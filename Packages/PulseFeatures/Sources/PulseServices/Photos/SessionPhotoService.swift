import Foundation
import PulseDomain

public enum SessionPhotoError: Error, Equatable {
    /// La séance a déjà `SessionPhoto.maxPerSession` photos.
    case full
    /// Les données ne sont pas une image lisible.
    case unreadable
}

/// Les photos d'une séance : traitement de l'image, limite de 6 par séance et rang d'affichage, au-dessus du dépôt. Un acteur :
/// le traitement de l'image (lecture, réduction, réencodage) tourne sur son exécuteur, jamais sur l'acteur principal.
public actor SessionPhotoService {
    private let repository: any SessionPhotoRepository
    private let timeZone: TimeZone
    private let now: @Sendable () -> Date
    /// Les ajouts passent l'un après l'autre : sans elle, deux ajouts concurrents liraient le même nombre de photos (l'acteur se
    /// libère à chaque `await`) et dépasseraient la limite ou partageraient un rang.
    private let queue = SerialTaskQueue()

    public init(repository: any SessionPhotoRepository, timeZone: TimeZone = .current, now: @escaping @Sendable () -> Date) {
        self.repository = repository
        self.timeZone = timeZone
        self.now = now
    }

    /// Les photos de la séance, dans leur ordre d'affichage.
    public func photos(for sessionID: UUID) async throws -> [SessionPhoto] {
        try await repository.photos(for: sessionID)
    }

    /// La vignette de la photo (JPEG) ; `nil` si elle n'existe pas ou a été supprimée.
    public func thumbnail(of photoID: UUID) async throws -> Data? {
        try await repository.image(of: photoID)?.thumbnail
    }

    /// L'image de la photo (JPEG) ; `nil` si elle n'existe pas ou a été supprimée.
    public func image(of photoID: UUID) async throws -> Data? {
        try await repository.image(of: photoID)?.image
    }

    /// Traite l'image hors de l'acteur principal, puis l'ajoute en dernier (`order` = plus grand + 1). Refuse une septième
    /// photo avec `.full`, des données illisibles avec `.unreadable` ; un échec de réencodage remonte tel quel.
    public func add(_ data: Data, to sessionID: UUID) async throws -> SessionPhoto {
        try await queue.run { try await self.append(data, to: sessionID) }
    }

    private func append(_ data: Data, to sessionID: UUID) async throws -> SessionPhoto {
        let existing = try await repository.photos(for: sessionID)
        guard SessionPhotoRules.remainingSlots(current: existing.count) > 0 else { throw SessionPhotoError.full }
        let processed: ProcessedPhoto
        do {
            processed = try PhotoProcessor.process(data, timeZone: timeZone)
        } catch PhotoProcessingError.unreadable {
            throw SessionPhotoError.unreadable
        }
        let date = now()
        let photo = SessionPhoto(id: UUID(), sessionID: sessionID, order: (existing.map(\.order).max() ?? -1) + 1,
                                 createdAt: date, updatedAt: date)
        try await repository.add(photo, image: processed.image)
        return photo
    }

    /// Supprime la photo ; une place se libère dans la séance.
    public func delete(photoID: UUID) async throws {
        try await repository.delete(photoID: photoID)
    }
}
