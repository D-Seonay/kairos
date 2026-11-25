import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataProfileRepository: ProfileRepository {
    /// Tri en mémoire : il n'y a jamais qu'un ou deux profils, et l'ordre par `id.uuidString` départage deux appareils.
    public func load() throws -> UserProfile? {
        let stored = try modelContext.fetch(FetchDescriptor<StoredProfile>(predicate: #Predicate { $0.deletedAt == nil }))
        return stored.min { lhs, rhs in
            lhs.createdAt != rhs.createdAt ? lhs.createdAt < rhs.createdAt : lhs.id.uuidString < rhs.id.uuidString
        }?.toDomain()
    }

    public func save(_ profile: UserProfile) throws {
        try write(profile)
    }

    /// Tout le corps est synchrone sur l'acteur : aucune autre écriture ne passe entre la lecture et l'enregistrement.
    @discardableResult
    public func update(_ transform: @Sendable (inout UserProfile) throws -> Void) throws -> ProfileUpdate? {
        guard let before = try load() else { return nil }
        var after = before
        try transform(&after)
        guard after != before else { return ProfileUpdate(before: before, after: before) }
        return ProfileUpdate(before: before, after: try write(after))
    }

    public func delete(id: UUID) throws {
        guard let stored = try modelContext.first(StoredProfile.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) else {
            return
        }
        let now = Date()
        stored.deletedAt = now
        stored.updatedAt = now
        try modelContext.save()
    }

    /// Enregistre le profil avec `updatedAt` à l'heure de l'écriture et le rend tel qu'enregistré.
    @discardableResult
    private func write(_ profile: UserProfile) throws -> UserProfile {
        var stamped = profile
        stamped.updatedAt = Date()
        let id = profile.id
        if let existing = try modelContext.first(StoredProfile.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredProfile(stamped))
        }
        try modelContext.save()
        return stamped
    }
}
