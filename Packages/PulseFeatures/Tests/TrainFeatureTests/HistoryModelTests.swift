import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TrainFeature

/// Un dépôt de séances dont la lecture échoue tant que `isFailing` est vrai.
private actor FlakyWorkoutRepository: WorkoutRepository {
    enum Failure: Error { case unreadable }

    private let base = InMemoryWorkoutRepository()
    var isFailing = true

    func recover() { isFailing = false }

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        if isFailing { throw Failure.unreadable }
        return try await base.sessions(from: from, to: to)
    }

    func session(id: UUID) async throws -> WorkoutSession? { try await base.session(id: id) }
    func save(_ session: WorkoutSession) async throws { try await base.save(session) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
    func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] { try await base.lastSets(for: exercise) }
}

@MainActor @Test func historyGroupsByMonthNewestFirst() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 9, day: 28, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)], source: .hevy)
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)], source: .hevy)
    try await fixture.log(on: TrainClock.date(month: 10, day: 27, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 3)],
                          status: .abandoned)
    let model = HistoryModel(environment: fixture.environment)
    await model.load()
    #expect(model.months.map(\.title) == ["octobre 2026", "septembre 2026"])
    #expect(model.months[0].sessions.map(\.isImported) == [false, true])
    #expect(model.months[0].sessions[0].isAbandoned)
    #expect(!model.months[0].sessions[1].isAbandoned)
    #expect(model.months[1].sessions.count == 1)
}

@MainActor @Test func historyLineSummarizesTheSession() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 5, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 5)])
    let date = TrainClock.date(month: 10, day: 12, hour: 18)
    let session = try await fixture.log(
        on: date, sets: [LoggedSet(weightKg: 40, reps: 10, type: .warmup), LoggedSet(weightKg: 80, reps: 5),
                         LoggedSet(weightKg: 80, reps: 4)], title: "Push")
    _ = try await fixture.environment.records.recomputeAll()
    let model = HistoryModel(environment: fixture.environment)
    await model.load()
    let line = try #require(model.months.first?.sessions.first)
    #expect(line.id == session.id)
    #expect(line.title == "Push")
    #expect(line.date == date)
    #expect(line.durationMinutes == 60)
    #expect(line.workingSets == 2)
    #expect(line.tonnageKg == 720)
    #expect(line.recordCount == 1)
    #expect(!line.isImported)
}

@MainActor @Test func historyLeavesOutSessionsInProgressAndRuns() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)])
    try await fixture.log(on: TrainClock.date(month: 10, day: 13, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)],
                          status: .inProgress)
    let date = TrainClock.date(month: 10, day: 14, hour: 7)
    try await fixture.environment.workouts.save(WorkoutSession(
        startedAt: date, endedAt: date.addingTimeInterval(1_800), kind: .run, source: .appleHealth, status: .completed,
        title: "Course", createdAt: date, updatedAt: date))
    let model = HistoryModel(environment: fixture.environment)
    await model.load()
    #expect(model.months.flatMap(\.sessions).count == 1)
}

@MainActor @Test func removingImportedSessionsKeepsThePulseOnes() async throws {
    let fixture = TrainFixture()
    try await fixture.log(on: TrainClock.date(month: 9, day: 28, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)], source: .hevy)
    try await fixture.log(on: TrainClock.date(month: 10, day: 12, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)], source: .hevy)
    let kept = try await fixture.log(on: TrainClock.date(month: 10, day: 27, hour: 18), sets: [LoggedSet(weightKg: 60, reps: 8)])
    let model = HistoryModel(environment: fixture.environment)
    await model.load()
    #expect(model.hasImportedSessions)
    let removed = try await model.removeImported()
    #expect(removed == 2)
    #expect(model.months.flatMap(\.sessions).map(\.id) == [kept.id])
    #expect(!model.hasImportedSessions)
}

@MainActor @Test func historyShowsAnErrorThenRecovers() async throws {
    let workouts = FlakyWorkoutRepository()
    let base = TrainFixture().environment
    var environment = base
    environment.workouts = workouts
    let model = HistoryModel(environment: environment)
    await model.load()
    #expect(model.errorMessage != nil)
    #expect(model.months.isEmpty)
    await workouts.recover()
    await model.load()
    #expect(model.errorMessage == nil)
    #expect(model.hasLoaded)
}
