import Foundation
import PulseDomain
import SwiftData

/// Une photo de séance, synchronisée avec iCloud : l'image (JPEG, grand côté 2 048 px) et sa vignette (400 px).
/// Tout est optionnel ou a une valeur par défaut et rien n'est unique, comme l'exige CloudKit.
/// Les deux images, volumineuses, sont rangées hors de la base (`externalStorage`).
@Model
public final class StoredSessionPhoto {
    public var id: UUID = UUID()
    public var sessionID: UUID?
    public var order: Int = 0
    @Attribute(.externalStorage) public var imageData: Data?
    @Attribute(.externalStorage) public var thumbnailData: Data?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ photo: SessionPhoto, image: PhotoImage) {
        id = photo.id
        sessionID = photo.sessionID
        order = photo.order
        imageData = image.image
        thumbnailData = image.thumbnail
        createdAt = photo.createdAt
        updatedAt = photo.updatedAt
    }

    /// Suppression logique : ne garde que la marque, jamais l'image ni la vignette.
    public func markDeleted(at date: Date) {
        imageData = nil
        thumbnailData = nil
        deletedAt = date
        updatedAt = date
    }

    public func toDomain() -> SessionPhoto {
        SessionPhoto(id: id, sessionID: sessionID ?? UUID(), order: order, createdAt: createdAt, updatedAt: updatedAt)
    }
}
