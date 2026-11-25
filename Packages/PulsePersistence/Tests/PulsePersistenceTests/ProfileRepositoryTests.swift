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

@Test func profileFirstNameSurvivesSave() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    try await repo.save(UserProfile(firstName: "Mathéo", createdAt: Fixed.t0, updatedAt: Fixed.t0))
    #expect(try await repo.load()?.firstName == "Mathéo")
}

@Test func profilesWithSameCreatedAtResolveByID() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    let profiles = (0..<4).map { _ in UserProfile(createdAt: Fixed.t1, updatedAt: Fixed.t1) }
    for profile in profiles {
        try await repo.save(profile)
    }
    let smallest = profiles.min { $0.id.uuidString < $1.id.uuidString }
    #expect(try await repo.load()?.id == smallest?.id)
}

@Test func deletedProfileIsNotLoaded() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    let older = UserProfile(createdAt: Fixed.t0, updatedAt: Fixed.t0)
    let newer = UserProfile(createdAt: Fixed.t2, updatedAt: Fixed.t2)
    try await repo.save(older)
    try await repo.save(newer)
    try await repo.delete(id: older.id)
    #expect(try await repo.load()?.id == newer.id)
    let context = ModelContext(repo.modelContainer)
    #expect(try context.fetchCount(FetchDescriptor<StoredProfile>()) == 2)
}

@Test func updateWithoutProfileWritesNothing() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    let result = try await repo.update { $0.heightCm = 180 }
    #expect(result == nil)
    #expect(try await repo.load() == nil)
}

@Test func updateChangesOnlyTheTransformedFields() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    try await repo.save(UserProfile(firstName: "Mathéo", heightCm: 180, createdAt: Fixed.t0, updatedAt: Fixed.t0))
    let before = Date()
    let result = try #require(try await repo.update { $0.weightKg = 75 })
    let loaded = try #require(try await repo.load())
    #expect(loaded.weightKg == 75 && loaded.firstName == "Mathéo" && loaded.heightCm == 180)
    #expect(result.didChange && result.before.weightKg == nil && result.after == loaded && loaded.updatedAt >= before)
}

@Test func unchangedUpdateIsNotWritten() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    try await repo.save(UserProfile(heightCm: 180, createdAt: Fixed.t0, updatedAt: Fixed.t0))
    let stored = try #require(try await repo.load())
    let result = try #require(try await repo.update { $0.heightCm = 180 })
    #expect(!result.didChange && result.after == stored)
    #expect(try await repo.load()?.updatedAt == stored.updatedAt)
}

@Test func throwingUpdateWritesNothing() async throws {
    struct Refused: Error {}
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    try await repo.save(UserProfile(heightCm: 180, createdAt: Fixed.t0, updatedAt: Fixed.t0))
    await #expect(throws: Refused.self) {
        try await repo.update { profile in
            profile.heightCm = 150
            throw Refused()
        }
    }
    #expect(try await repo.load()?.heightCm == 180)
}

/// Des mises à jour concurrentes de champs différents s'appliquent toutes : aucune ne repart d'une lecture périmée (issue #72).
@Test func concurrentUpdatesOfDifferentFieldsAreAllKept() async throws {
    let repo = SwiftDataProfileRepository(modelContainer: try TestContainer.make())
    try await repo.save(UserProfile(createdAt: Fixed.t0, updatedAt: Fixed.t0))
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { try await repo.update { $0.firstName = "Léa" } }
        group.addTask { try await repo.update { $0.weightKg = 75 } }
        group.addTask { try await repo.update { $0.barWeightKg = 15 } }
        group.addTask { try await repo.update { $0.defaultRestSeconds = 120 } }
        try await group.waitForAll()
    }
    let loaded = try #require(try await repo.load())
    #expect(loaded.firstName == "Léa" && loaded.weightKg == 75 && loaded.barWeightKg == 15 && loaded.defaultRestSeconds == 120)
}
