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
        var stamped = profile
        stamped.updatedAt = Date()
        let id = profile.id
        if let existing = try modelContext.first(StoredProfile.self, where: #Predicate { $0.id == id && $0.deletedAt == nil }) {
            existing.apply(stamped)
        } else {
            modelContext.insert(StoredProfile(stamped))
        }
        try modelContext.save()
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
}
