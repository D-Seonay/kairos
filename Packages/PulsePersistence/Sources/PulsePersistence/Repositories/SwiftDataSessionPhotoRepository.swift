import Foundation
import PulseDomain
import SwiftData

/// Les photos des séances, dans le magasin synchronisé : elles suivent la séance dans iCloud.
/// La suppression est logique, comme celle du tracé : le miroir CloudKit propage la marque, sans l'image ni la vignette.
@ModelActor
public actor SwiftDataSessionPhotoRepository: SessionPhotoRepository {
    public func photos(for sessionID: UUID) throws -> [SessionPhoto] {
        let rows = try modelContext.fetch(FetchDescriptor<StoredSessionPhoto>(
            predicate: #Predicate { $0.sessionID == sessionID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)]))
        return rows.map { $0.toDomain() }
    }

    public func image(of photoID: UUID) throws -> PhotoImage? {
        var descriptor = FetchDescriptor<StoredSessionPhoto>(predicate: #Predicate { $0.id == photoID && $0.deletedAt == nil },
                                                             sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let row = try modelContext.fetch(descriptor).first, let image = row.imageData, let thumbnail = row.thumbnailData else {
            return nil
        }
        return PhotoImage(image: image, thumbnail: thumbnail)
    }

    public func add(_ photo: SessionPhoto, image: PhotoImage) throws {
        modelContext.insert(StoredSessionPhoto(photo, image: image))
        try modelContext.save()
    }

    public func delete(photoID: UUID) throws {
        let rows = try modelContext.fetch(FetchDescriptor<StoredSessionPhoto>(
            predicate: #Predicate { $0.id == photoID && $0.deletedAt == nil }))
        guard !rows.isEmpty else { return }
        let now = Date()
        for row in rows {
            row.markDeleted(at: now)
        }
        try modelContext.save()
    }

    public func deleteAll(sessionID: UUID) throws {
        guard try modelContext.markSessionPhotosDeleted(sessionID: sessionID, at: Date()) else { return }
        try modelContext.save()
    }
}

extension ModelContext {
    /// Marque supprimées les photos vivantes de la séance, sans enregistrer ; vrai si au moins une l'a été.
    /// Seule la marque part dans iCloud : l'image et la vignette sont effacées.
    @discardableResult
    func markSessionPhotosDeleted(sessionID: UUID, at date: Date) throws -> Bool {
        let rows = try fetch(FetchDescriptor<StoredSessionPhoto>(
            predicate: #Predicate { $0.sessionID == sessionID && $0.deletedAt == nil }))
        for row in rows {
            row.markDeleted(at: date)
        }
        return !rows.isEmpty
    }
}
