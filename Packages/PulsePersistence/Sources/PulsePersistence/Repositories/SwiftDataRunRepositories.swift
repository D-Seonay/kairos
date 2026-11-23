import Foundation
import PulseDomain
import SwiftData

/// Le tracé des courses, dans le magasin synchronisé. Sans clé unique (CloudKit), deux appareils peuvent créer chacun une
/// ligne pour la même séance : la lecture prend la plus récente et la suppression les marque toutes.
@ModelActor
public actor SwiftDataRunTrackRepository: RunTrackRepository {
    public func track(for sessionID: UUID) throws -> RunTrack? {
        var descriptor = FetchDescriptor<StoredRunTrack>(predicate: #Predicate { $0.id == sessionID && $0.deletedAt == nil },
                                                         sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    /// Met à jour la ligne de la séance, même marquée supprimée (elle revient), ou en crée une.
    public func save(_ track: RunTrack) throws {
        var stamped = track
        stamped.updatedAt = Date()
        let id = track.id
        let rows = try modelContext.fetch(FetchDescriptor<StoredRunTrack>(predicate: #Predicate { $0.id == id },
                                                                          sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        if let existing = rows.first(where: { $0.deletedAt == nil }) ?? rows.first {
            existing.deletedAt = nil
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredRunTrack(stamped))
        }
        try modelContext.save()
    }

    /// Suppression logique, comme les séances : le miroir CloudKit propage la marque, sans les coordonnées.
    public func delete(sessionID: UUID) throws {
        guard try modelContext.markRunTracksDeleted(sessionID: sessionID, at: Date()) else { return }
        try modelContext.save()
    }
}

extension ModelContext {
    /// Marque supprimées les lignes vivantes du tracé de la séance, sans enregistrer ; vrai si au moins une l'a été.
    /// Seule la marque part dans iCloud : les coordonnées, les temps par km et le dénivelé sont effacés.
    @discardableResult
    func markRunTracksDeleted(sessionID: UUID, at date: Date) throws -> Bool {
        let rows = try fetch(FetchDescriptor<StoredRunTrack>(predicate: #Predicate { $0.id == sessionID && $0.deletedAt == nil }))
        for row in rows {
            row.markDeleted(at: date)
        }
        return !rows.isEmpty
    }
}

/// Un seul emplacement, local : le brouillon de la course en cours.
@ModelActor
public actor SwiftDataRunDraftStore: RunDraftStore {
    public func load() throws -> RunDraft? {
        try modelContext.fetch(FetchDescriptor<StoredRunDraft>()).first?.toDomain()
    }

    /// Réécrit la ligne de la même course sur place ; le brouillon d'une autre course est remplacé.
    public func save(_ draft: RunDraft) throws {
        let id = draft.sessionID
        try modelContext.delete(model: StoredRunDraft.self, where: #Predicate { $0.id != id })
        if let existing = try modelContext.first(StoredRunDraft.self, where: #Predicate { $0.id == id }) {
            try existing.apply(draft)
        } else {
            modelContext.insert(try StoredRunDraft(draft))
        }
        try modelContext.save()
    }

    public func clear() throws {
        try modelContext.delete(model: StoredRunDraft.self)
        try modelContext.save()
    }
}
