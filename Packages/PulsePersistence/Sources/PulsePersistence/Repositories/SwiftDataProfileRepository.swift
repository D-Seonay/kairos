import Foundation
import PulseDomain
import SwiftData

@ModelActor
public actor SwiftDataProfileRepository: ProfileRepository {
    public func load() throws -> UserProfile? {
        var descriptor = FetchDescriptor<StoredProfile>(predicate: #Predicate { $0.deletedAt == nil },
                                                        sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
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
}
