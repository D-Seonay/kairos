import Foundation
import PulseDomain
import SwiftData

/// Le brouillon de la course en cours, local seulement : il porte les FC lues dans Apple Santé (frontière M8).
/// `id` est celui de la séance, clé unique (le magasin local n'est pas soumis aux règles de CloudKit).
@Model
public final class StoredRunDraft {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Le `RunDraft` entier, en JSON.
    public var payload: Data?
    public var updatedAt: Date = Date()

    public init(_ draft: RunDraft) throws {
        id = draft.sessionID
        try apply(draft)
    }

    public func apply(_ draft: RunDraft) throws {
        payload = try JSONEncoder().encode(draft)
        updatedAt = draft.updatedAt
    }

    /// `nil` si le contenu ne se relit plus (format d'une version antérieure) : la course n'est alors plus reprenable.
    public func toDomain() -> RunDraft? {
        payload.flatMap { try? JSONDecoder().decode(RunDraft.self, from: $0) }
    }
}
