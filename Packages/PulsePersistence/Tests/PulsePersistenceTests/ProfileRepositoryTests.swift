import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func profileSaveThenLoadAndUpdate() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    #expect(try await repo.load() == nil)
    var profile = UserProfile(createdAt: Fixed.t1, updatedAt: Fixed.t1)
    profile.heightCm = 180
    let before = Date()
    try await repo.save(profile)
    let loaded = try #require(try await repo.load())
    #expect(loaded.id == profile.id && loaded.heightCm == 180)
    #expect(loaded.createdAt == Fixed.t1 && loaded.updatedAt >= before)
    profile.heightCm = 181
    try await repo.save(profile)
    #expect(try await repo.load()?.heightCm == 181)
    let context = ModelContext(repo.modelContainer)
    #expect(try context.fetchCount(FetchDescriptor<StoredProfile>()) == 1)
}

@Test func loadPrefersOldestProfileWhenDuplicatesExist() async throws {   // Review Focus 1
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    let newer = UserProfile(createdAt: Fixed.t2, updatedAt: Fixed.t2)
    let older = UserProfile(createdAt: Fixed.t0, updatedAt: Fixed.t0)
    try await repo.save(newer)
    try await repo.save(older)
    #expect(try await repo.load()?.id == older.id)
}
