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

    public init(service: SessionPhotoService, sessionID: UUID, calendar: Calendar) {
        self.service = service
        self.sessionID = sessionID
        self.calendar = calendar
    }

    public var remainingSlots: Int { SessionPhotoRules.remainingSlots(current: photos.count) }
    public var canAdd: Bool { remainingSlots > 0 }

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
        errorMessage = nil
        let kept = items.prefix(remainingSlots)
        var dropped = items.count - kept.count
        var unreadable = 0
        var failed = false
        var added = 0
        addsInFlight += 1
        isAdding = true
        for data in kept {
            do {
                let photo = try await service.add(data, to: sessionID)
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
        errorMessage = message(dropped: dropped, unreadable: unreadable, failed: failed)
        if added > 0 { announce(PhotoText.photosAdded(added)) }
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

    /// L'image entière (JPEG) de la photo, pour la visionneuse et le partage ; `nil` si elle n'existe plus.
    public func image(of photoID: UUID) async -> Data? {
        try? await service.image(of: photoID)
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
