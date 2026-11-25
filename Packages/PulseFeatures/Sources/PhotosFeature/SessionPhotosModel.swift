import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de la section Photos d'une séance : les photos, leurs vignettes, l'ajout et la suppression. L'ajout ne bloque rien :
/// le traitement de l'image tourne dans le service (hors de l'acteur principal), le modèle ne fait qu'attendre sa réponse.
@MainActor @Observable
public final class SessionPhotosModel {
    public private(set) var photos: [SessionPhoto] = []
    public private(set) var thumbnails: [UUID: Data] = [:]
    /// Vrai tant qu'au moins un ajout est en cours : la vue montre une case « en cours ».
    public private(set) var isAdding = false
    public private(set) var errorMessage: String?
    /// La dernière annonce VoiceOver (« Photo ajoutée », « Photo supprimée ») ; la vue la poste.
    public private(set) var announcement: String?
    /// Change à chaque annonce : deux « Photo ajoutée » de suite se disent deux fois.
    public private(set) var announcementSerial = 0

    @ObservationIgnored private let service: SessionPhotoService
    @ObservationIgnored private let sessionID: UUID
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var addsInFlight = 0
    /// Vrai une fois la séance abandonnée sans être enregistrée (`discard`) : plus rien ne s'ajoute.
    @ObservationIgnored public private(set) var isDiscarded = false

    public init(service: SessionPhotoService, sessionID: UUID, calendar: Calendar) {
        self.service = service
        self.sessionID = sessionID
        self.calendar = calendar
    }

    public var remainingSlots: Int { SessionPhotoRules.remainingSlots(current: photos.count) }
    public var canAdd: Bool { remainingSlots > 0 && !isDiscarded }

    /// Lit les photos de la séance et les vignettes qui manquent.
    public func load() async {
        do {
            let loaded = try await service.photos(for: sessionID)
            photos = loaded
            await fetchMissingThumbnails()
            thumbnails = thumbnails.filter { entry in loaded.contains { $0.id == entry.key } }
        } catch {
            errorMessage = PhotoText.loadFailed
        }
    }

    /// Garde les premières données dans la limite ; au-delà, `errorMessage` le dit. Une image illisible est sautée et signalée.
    public func add(_ items: [Data]) async {
        await add(loading: items.map { data in { data } })
    }

    /// Comme `add(_:)`, mais l'état « en cours » commence avant que les images soient lues : un original iCloud ou l'encodage
    /// d'une photo prise peut durer des secondes. Les chargeurs au-delà de la limite ne sont pas appelés, et un seul original
    /// est en mémoire à la fois. Un chargeur qui rend `nil` compte comme une image illisible.
    public func add(loading loaders: [@Sendable () async -> Data?]) async {
        errorMessage = nil
        let kept = loaders.prefix(remainingSlots)
        var dropped = loaders.count - kept.count
        var unreadable = 0
        var failed = false
        var added = 0
        addsInFlight += 1
        isAdding = true
        for loader in kept {
            guard !isDiscarded else { break }
            do {
                let data = await loader() ?? Data()
                guard !isDiscarded else { break }
                let photo = try await service.add(data, to: sessionID)
                // La séance a été abandonnée pendant l'ajout : la photo arrivée trop tard ne reste pas dans iCloud.
                guard !isDiscarded else {
                    try? await service.delete(photoID: photo.id)
                    break
                }
                append(photo)
                await fetchMissingThumbnails()
                added += 1
            } catch SessionPhotoError.full {
                dropped += 1
            } catch SessionPhotoError.unreadable {
                unreadable += 1
            } catch {
                failed = true
            }
        }
        addsInFlight -= 1
        isAdding = addsInFlight > 0
        guard !isDiscarded else { return }
        errorMessage = message(dropped: dropped, unreadable: unreadable, failed: failed)
        if added > 0 { announce(PhotoText.photosAdded(added)) }
    }

    /// La séance a été abandonnée sans être enregistrée : les ajouts en cours s'arrêtent, une photo qui arrive encore est
    /// supprimée, et celles déjà ajoutées le sont aussi (suppression logique, l'image est effacée). L'abandon les a déjà
    /// supprimées, mais un ajout qui finissait pendant l'abandon pouvait en laisser une, sans séance, dans iCloud. Idempotent.
    public func discard() async {
        isDiscarded = true
        photos = []
        thumbnails = [:]
        try? await service.deleteAll(sessionID: sessionID)
    }

    /// Supprime la photo ; une place se libère.
    public func delete(_ photoID: UUID) async {
        do {
            try await service.delete(photoID: photoID)
            photos.removeAll { $0.id == photoID }
            thumbnails[photoID] = nil
            errorMessage = nil
            announce(PhotoText.photoDeleted)
        } catch {
            errorMessage = PhotoText.deleteFailed
        }
    }

    /// L'image entière (JPEG) de la photo, pour la visionneuse et le partage ; `nil` si elle n'existe plus ou ne se lit pas (dans
    /// ce cas, `errorMessage` le dit).
    public func image(of photoID: UUID) async -> Data? {
        do {
            return try await service.image(of: photoID)
        } catch {
            errorMessage = PhotoText.imageUnavailable
            return nil
        }
    }

    /// « Photo 2 sur 4, ajoutée à 18 h 42 ».
    public func spokenLabel(of photo: SessionPhoto) -> String {
        let index = photos.firstIndex { $0.id == photo.id } ?? 0
        return PhotoText.sessionPhotoLabel(index: index + 1, count: max(photos.count, 1), addedAt: photo.createdAt,
                                           calendar: calendar)
    }

    private func append(_ photo: SessionPhoto) {
        guard !photos.contains(where: { $0.id == photo.id }) else { return }
        photos.append(photo)
        photos.sort { $0.order < $1.order }
    }

    private func fetchMissingThumbnails() async {
        for photo in photos where thumbnails[photo.id] == nil {
            if let data = try? await service.thumbnail(of: photo.id) { thumbnails[photo.id] = data }
        }
    }

    private func announce(_ text: String) {
        announcement = text
        announcementSerial += 1
    }

    private func message(dropped: Int, unreadable: Int, failed: Bool) -> String? {
        if dropped > 0 { return PhotoText.overLimit(dropped: dropped) }
        if unreadable > 1 { return PhotoText.unreadableImages }
        if unreadable == 1 { return PhotoText.unreadableImage }
        return failed ? PhotoText.addFailed : nil
    }
}
