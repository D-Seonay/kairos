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

private func benchSet(order: Int, reps: Int, type: SetType = .working) -> WorkoutSet {
    var set = Sample.set(order: order, type: type)
    set.actualReps = reps
    return set
}

private func benchSession(day offset: Int, status: SessionStatus, sets: [WorkoutSet]) -> WorkoutSession {
    var session = Sample.session(startedAt: Fixed.t0.addingTimeInterval(TimeInterval(offset) * day), status: status, sets: 0)
    session.sets = sets
    return session
}

@Test func lastSetsComeFromTheLatestCompletedOrAbandonedSessionWithoutWarmups() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let completed = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 10, type: .warmup),
                                                                    benchSet(order: 2, reps: 12), benchSet(order: 3, reps: 5)])
    let abandoned = benchSession(day: 9, status: .abandoned, sets: [benchSet(order: 1, reps: 10)])
    let live = benchSession(day: 14, status: .inProgress, sets: [benchSet(order: 1, reps: 8)])
    let deleted = benchSession(day: 15, status: .completed, sets: [benchSet(order: 1, reps: 6)])
    for session in [completed, abandoned, live, deleted] { try await repo.save(session) }
    try await repo.delete(id: deleted.id)

    let bench = ExerciseReference.content(id: "bench-press-barbell")
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [10])
    try await repo.delete(id: abandoned.id)
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [12, 5])
}

@Test func failureAndDropSetsCountAsLastTime() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let session = benchSession(day: 1, status: .completed, sets: [
        benchSet(order: 4, reps: 4, type: .failure), benchSet(order: 1, reps: 10, type: .warmup), benchSet(order: 2, reps: 8),
        benchSet(order: 3, reps: 6, type: .drop)])
    try await repo.save(session)
    let sets = try await repo.lastSets(for: .content(id: "bench-press-barbell"))
    #expect(sets.map(\.setType) == [.working, .drop, .failure] && sets.map(\.order) == [2, 3, 4])
}

@Test func lastSetsFindsAUserExerciseAndIgnoresOtherExercises() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let custom = ExerciseReference.user(id: UUID())
    var session = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9)])
    session.sets.append(Sample.set(order: 2, exercise: custom))
    try await repo.save(session)
    #expect(try await repo.lastSets(for: custom).map(\.order) == [2])
    #expect(try await repo.lastSets(for: .user(id: UUID())).isEmpty)
}

@Test func aNewerSessionWithOnlyWarmupsOfTheExerciseDoesNotHideLastTime() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let older = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9), benchSet(order: 2, reps: 7)])
    let warmupOnly = benchSession(day: 5, status: .abandoned, sets: [benchSet(order: 1, reps: 15, type: .warmup)])
    for session in [older, warmupOnly] { try await repo.save(session) }
    #expect(try await repo.lastSets(for: .content(id: "bench-press-barbell")).map(\.actualReps) == [9, 7])
}
