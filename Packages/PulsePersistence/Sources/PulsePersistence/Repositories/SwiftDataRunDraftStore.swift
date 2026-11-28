import Foundation
import PulseDomain
import SwiftData

/// Un seul emplacement, local : le brouillon de la course en cours. Une course ne fait qu'ajouter des points et des FC : chaque
/// sauvegarde (toutes les 10 s) réécrit l'en-tête, de taille fixe, et ajoute un paquet des seuls points et FC nouveaux, dans un
/// même `save()`. Le coût d'une sauvegarde ne grossit donc plus avec la durée de la course. Un tracé qui ne prolonge plus ce qui
/// est écrit (autre course, points retirés) est réécrit en entier.
@ModelActor
public actor SwiftDataRunDraftStore: RunDraftStore {
    /// Un brouillon d'avant la V9 (tout dans l'en-tête) se relit tel quel ; `nil` si l'en-tête ou un paquet ne se relit plus.
    public func load() throws -> RunDraft? {
        guard let header = try modelContext.fetch(FetchDescriptor<StoredRunDraft>()).first,
              var draft = header.decodedPayload() else { return nil }
        guard header.isChunked else { return draft }
        let id = header.id
        let chunks = try modelContext.fetch(FetchDescriptor<StoredRunDraftChunk>(
            predicate: #Predicate { $0.draftID == id }, sortBy: [SortDescriptor(\.order)]))
        do {
            draft.points = try chunks.flatMap { try $0.decodedPoints() }
            draft.heartRates = try chunks.flatMap { try $0.decodedHeartRates() }
        } catch {
            return nil
        }
        return draft
    }

    /// Le brouillon d'une autre course est remplacé.
    public func save(_ draft: RunDraft) throws {
        let id = draft.sessionID
        try modelContext.delete(model: StoredRunDraft.self, where: #Predicate { $0.id != id })
        try modelContext.delete(model: StoredRunDraftChunk.self, where: #Predicate { $0.draftID != id })
        if let header = try modelContext.first(StoredRunDraft.self, where: #Predicate { $0.id == id }), Self.extends(header, with: draft) {
            try append(draft, to: header)
        } else {
            try rewrite(draft)
        }
        try modelContext.save()
    }

    public func clear() throws {
        try modelContext.delete(model: StoredRunDraft.self)
        try modelContext.delete(model: StoredRunDraftChunk.self)
        try modelContext.save()
    }

    /// Vrai si `draft` prolonge ce qui est déjà écrit en paquets : rien n'a été retiré et le dernier point écrit est à sa place.
    static func extends(_ header: StoredRunDraft, with draft: RunDraft) -> Bool {
        guard header.isChunked, draft.points.count >= header.storedPointCount,
              draft.heartRates.count >= header.storedHeartRateCount else { return false }
        guard header.storedPointCount > 0 else { return true }
        return draft.points[header.storedPointCount - 1].timestamp == header.lastPointAt
    }

    /// Réécrit l'en-tête et ajoute un paquet des points et FC nouveaux, s'il y en a.
    private func append(_ draft: RunDraft, to header: StoredRunDraft) throws {
        let points = draft.points[header.storedPointCount...]
        let heartRates = draft.heartRates[header.storedHeartRateCount...]
        if !points.isEmpty || !heartRates.isEmpty {
            modelContext.insert(try StoredRunDraftChunk(draftID: header.id, order: header.chunkCount, points: points,
                                                        heartRates: heartRates))
            header.chunkCount += 1
        }
        try header.writeHeader(draft)
        record(draft, in: header)
    }

    /// Repart de zéro : l'en-tête, et un seul paquet avec tout le tracé et toutes les FC.
    private func rewrite(_ draft: RunDraft) throws {
        let id = draft.sessionID
        try modelContext.delete(model: StoredRunDraftChunk.self, where: #Predicate { $0.draftID == id })
        let header: StoredRunDraft
        if let existing = try modelContext.first(StoredRunDraft.self, where: #Predicate { $0.id == id }) {
            header = existing
        } else {
            header = StoredRunDraft(id: id)
            modelContext.insert(header)
        }
        header.chunkCount = 0
        header.storedPointCount = 0
        header.storedHeartRateCount = 0
        header.lastPointAt = nil
        header.isChunked = true
        try append(draft, to: header)
    }

    private func record(_ draft: RunDraft, in header: StoredRunDraft) {
        header.storedPointCount = draft.points.count
        header.storedHeartRateCount = draft.heartRates.count
        header.lastPointAt = draft.points.last?.timestamp
    }
}
