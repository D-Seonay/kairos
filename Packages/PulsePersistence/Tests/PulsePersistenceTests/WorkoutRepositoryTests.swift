import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

private let day: TimeInterval = 86_400

@Test func sessionsFilterByRangeAndSortAscending() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let late = Sample.session(startedAt: Fixed.t0.addingTimeInterval(2 * day), sets: 1)
    let early = Sample.session(startedAt: Fixed.t0, sets: 1)
    let outside = Sample.session(startedAt: Fixed.t0.addingTimeInterval(5 * day), sets: 1)
    for session in [late, early, outside] { try await repo.save(session) }
    let found = try await repo.sessions(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(5 * day))
    #expect(found.map(\.id) == [early.id, late.id])
    try await repo.delete(id: early.id)
    #expect(try await repo.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [late.id, outside.id])
}

@Test func saveSessionUpdatesSetsInPlace() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    var session = Sample.session(sets: 3)
    try await repo.save(session)
    session.sets[1].actualReps = 12
    session.sets.removeLast()
    let before = Date()
    try await repo.save(session)
    let loaded = try #require(try await repo.session(id: session.id))
    #expect(loaded.sets.count == 2 && loaded.sets[1].actualReps == 12 && loaded.updatedAt >= before)
    let context = ModelContext(repo.modelContainer)
    let sets = try context.fetch(FetchDescriptor<StoredWorkoutSet>())
    #expect(sets.count == 3 && sets.filter { $0.deletedAt != nil }.count == 1)
}

@Test func lastSetsReturnsWorkingSetsOfLatestCompletedSession() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let squat = ExerciseReference.content(id: "back-squat-barbell")
    var sessionA = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-3 * day), sets: 0)
    sessionA.sets = [Sample.set(order: 1, exercise: squat, type: .warmup), Sample.set(order: 2, exercise: squat),
                     Sample.set(order: 3, exercise: squat)]
    var sessionB = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-1 * day), sets: 0)
    sessionB.sets = [Sample.set(order: 1), Sample.set(order: 2, exercise: squat), Sample.set(order: 3, exercise: squat),
                     Sample.set(order: 4, exercise: squat)]
    var sessionC = Sample.session(startedAt: Fixed.t0, status: .inProgress, sets: 0)
    sessionC.sets = [Sample.set(order: 1, exercise: squat)]
    for session in [sessionA, sessionB, sessionC] { try await repo.save(session) }
    let sets = try await repo.lastSets(for: squat)
    #expect(sets.count == 3 && sets.allSatisfy { $0.setType == .working } && sets.map(\.order) == [2, 3, 4])
    #expect(try await repo.lastSets(for: .content(id: "unknown")).isEmpty)
}
