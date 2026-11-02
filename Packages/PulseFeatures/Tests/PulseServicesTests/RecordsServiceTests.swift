import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RecordsServiceTests {
    private let store = InMemoryWorkoutRepository()
    private let counting: CountingWorkoutRepository
    private let records = InMemoryPersonalRecordRepository()
    private let service: RecordsService
    private let now = TestClock.date("2026-11-02T09:00")
    private let bench = ExerciseReference.content(id: "bench-press-barbell")

    init() {
        counting = CountingWorkoutRepository(inner: store)
        let now = now
        service = RecordsService(workouts: counting, records: records, userExercises: InMemoryUserExerciseRepository(),
                                 library: .bundled, now: { now })
    }

    private func session(_ start: String, weight: Double, flagged: Bool = false,
                         status: SessionStatus = .completed) -> WorkoutSession {
        let set = WorkoutSet(order: 0, exercise: bench, exerciseName: "Développé couché à la barre", setType: .working,
                             actualWeightKg: weight, actualReps: 5, isPersonalRecord: flagged)
        return WorkoutSession(startedAt: TestClock.date(start), kind: .strength, source: .pulse, status: status, title: "Push",
                              sets: [set], createdAt: .t0, updatedAt: .t0)
    }

    @Test func recomputeOnlyResavesSessionsWhoseFlagsChange() async throws {
        let first = session("2026-10-20T07:00", weight: 60)
        let record = session("2026-10-22T07:00", weight: 70)
        let lighter = session("2026-10-24T07:00", weight: 50, flagged: true)
        for seeded in [first, record, lighter] { try await store.save(seeded) }

        // Le 1er jour fonde la charge maximale et le 1RM estimé, le 2e les bat ; le 3e ne bat rien.
        #expect(try await service.recomputeAll() == 4)
        #expect(await counting.saveCount == 2)
        #expect(try await store.session(id: first.id) == first)
        let resaved = try #require(try await store.session(id: record.id))
        #expect(resaved.sets.map(\.isPersonalRecord) == [true] && resaved.updatedAt == now)
        #expect(try await store.session(id: lighter.id)?.sets.map(\.isPersonalRecord) == [false])
        #expect(Set(try await records.records(for: nil).map(\.sessionID)) == [first.id, record.id])

        #expect(try await service.recomputeAll() == 4)
        #expect(await counting.saveCount == 2)
    }

    @Test func recomputeLeavesSessionsInProgressAlone() async throws {
        let first = session("2026-10-20T07:00", weight: 60)
        let live = session("2026-11-02T08:30", weight: 80, flagged: true, status: .inProgress)
        for seeded in [first, live] { try await store.save(seeded) }

        #expect(try await service.recomputeAll() == 2)
        #expect(await counting.saveCount == 0)
        #expect(try await store.session(id: live.id) == live)
    }

    @Test func recomputeKeepsTheIdentityOfUnchangedRecords() async throws {
        try await store.save(session("2026-10-20T07:00", weight: 60))
        _ = try await service.recomputeAll()
        let before = try await records.records(for: nil).map(\.id)

        try await store.save(session("2026-10-22T07:00", weight: 50))
        #expect(try await service.recomputeAll() == 2)
        #expect(try await records.records(for: nil).map(\.id) == before)
    }

    @Test func recomputeAppliesFlagsToAFreshCopy() async throws {
        let first = session("2026-10-20T07:00", weight: 60)
        let record = session("2026-10-22T07:00", weight: 70)
        let edited = EditedNoteWorkoutRepository(inner: store, note: "Modifiée pendant le recalcul")
        let service = RecordsService(workouts: edited, records: records, userExercises: InMemoryUserExerciseRepository(),
                                     library: .bundled, now: { now })
        for seeded in [first, record] { try await store.save(seeded) }

        #expect(try await service.recomputeAll() == 4)
        let resaved = try #require(try await store.session(id: record.id))
        #expect(resaved.sets.map(\.isPersonalRecord) == [true])
        #expect(resaved.note == "Modifiée pendant le recalcul")
    }
}

/// Un dépôt dont la lecture d'une séance rend une note modifiée depuis la lecture de l'historique.
private struct EditedNoteWorkoutRepository: WorkoutRepository {
    let inner: any WorkoutRepository
    let note: String

    func sessions(from: Date, to: Date) async throws -> [WorkoutSession] {
        try await inner.sessions(from: from, to: to)
    }

    func session(id: UUID) async throws -> WorkoutSession? {
        guard var session = try await inner.session(id: id) else { return nil }
        session.note = note
        return session
    }

    func save(_ session: WorkoutSession) async throws {
        try await inner.save(session)
    }

    func delete(id: UUID) async throws {
        try await inner.delete(id: id)
    }

    func lastSets(for exercise: ExerciseReference) async throws -> [WorkoutSet] {
        try await inner.lastSets(for: exercise)
    }
}
