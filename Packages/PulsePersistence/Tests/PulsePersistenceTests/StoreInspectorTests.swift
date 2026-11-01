import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func inspectorCountsEveryTable() async throws {
    let container = try TestContainer.make()
    let inspector = SwiftDataStoreInspector(container: container, cloudEnabled: false)
    #expect(await inspector.cloudAccountStatus() == .unknown)
    try await SwiftDataProfileRepository(modelContainer: container).save(UserProfile())
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    try await workouts.save(Sample.session(sets: 3))
    let deleted = Sample.session(sets: 2)
    try await workouts.save(deleted)
    try await workouts.delete(id: deleted.id)
    let counts = try await inspector.counts()
    #expect(counts.count == StoreTable.allCases.count)
    #expect(counts[.profile] == 1 && counts[.workoutSessions] == 1 && counts[.workoutSets] == 3)
    #expect(counts[.programs] == 0 && counts[.cachedHealthSamples] == 0)
}
