import Foundation
import PulseDomain
import PulseServices
import Testing

struct ActiveSessionFinishTests {
    private typealias Fix = FinishFixtures
    private let fixture = ActiveSessionFixture()
    private let ended = TestClock.date("2026-11-02T08:55")

    /// Bench avec une note, pec deck sans série validée, un ajustement appliqué et un refusé.
    private func benchSession() -> LiveSession {
        Fix.session([Fix.bench(Fix.benchSets(), note: "Prise serrée"), Fix.pecDeck([Fix.set(40, 10)], note: "  ")],
                    applied: [SessionAdjustment(kind: .volume, reason: "Une série en moins")],
                    refused: [SessionAdjustment(kind: .rest, reason: "Repos +45 s")])
    }

    @Test func finishWritesOnlyValidatedSetsAndClearsEverything() async throws {
        try await fixture.seedHistory(LiveFixtures.rampingBench)
        let live = benchSession()
        let service = try await fixture.resume(live)
        let saved = try await service.finish(overallRPE: 8, note: "Bonne séance", endedAt: ended)
        #expect(saved.id == live.id && saved.status == .completed && saved.source == .pulse && saved.kind == .strength)
        #expect(saved.title == "Push" && saved.startedAt == Fix.start && saved.endedAt == ended)
        #expect(saved.overallRPE == 8 && saved.note == "Bonne séance" && saved.durationMinutes == 55)
        #expect(saved.tonnageKg == 1_082.5)   // 60 × 12 + 72,5 × 5
        #expect(saved.appliedAdjustments == live.appliedAdjustments && saved.refusedAdjustments == live.refusedAdjustments)
        #expect(saved.exerciseNotes == [ExerciseNote(exercise: LiveFixtures.bench, text: "Prise serrée")])
        #expect(saved.sets.map(\.order) == [0, 1, 2])
        #expect(saved.sets.map(\.id) == live.exercises[0].sets.prefix(3).map(\.id))
        #expect(saved.sets.map(\.setType) == [.warmup, .working, .working])
        let heaviest = saved.sets[2]
        #expect(heaviest.plannedWeightKg == 70 && heaviest.plannedReps == 5)
        #expect(heaviest.actualWeightKg == 72.5 && heaviest.actualReps == 5)
        #expect(heaviest.exerciseName == "Développé couché à la barre" && heaviest.restSeconds == 90)
        #expect(heaviest.completedAt == TestClock.date("2026-11-02T08:40"))
        // Les records sont recalculés : la série à 72,5 kg est marquée, dans la séance rendue comme dans la base.
        #expect(saved.sets.map(\.isPersonalRecord) == [false, false, true])
        #expect(try await fixture.workouts.session(id: live.id) == saved)
        #expect(try await fixture.store.load() == nil)
        #expect(await fixture.activity.endCount == 1)
        #expect(await fixture.notifier.cancelCount == 1)
        #expect(await service.current() == nil)
    }

    @Test func aFailedSaveKeepsTheSnapshotAndRetriesOnce() async throws {
        let fixture = ActiveSessionFixture(failingWorkoutSaveAt: 1)
        let live = benchSession()
        let service = try await fixture.resume(live)
        await #expect(throws: CountingWorkoutRepository.Failure.interrupted) {
            try await service.finish(overallRPE: 8, note: nil, endedAt: ended)
        }
        #expect(try await fixture.stored() == live)
        #expect(await fixture.activity.endCount == 0)
        #expect(await fixture.notifier.cancelCount == 0)
        let saved = try await service.finish(overallRPE: 8, note: nil, endedAt: ended)
        let all = try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture)
        #expect(all.map(\.id) == [live.id])
        #expect(all.first?.sets.count == 3 && saved.id == live.id)
        #expect(try await fixture.store.load() == nil)
        #expect(await fixture.activity.endCount == 1)
    }

    @Test func finishWithoutSessionThrows() async throws {
        let service = fixture.makeService()
        await #expect(throws: ActiveSessionError.noSession) {
            try await service.finish(overallRPE: 7, note: nil, endedAt: ended)
        }
    }

    @Test func abandonKeepsValidatedSetsAsAbandoned() async throws {
        let live = benchSession()
        let service = try await fixture.resume(live)
        let saved = try await service.abandon(endedAt: ended)
        #expect(saved.id == live.id && saved.status == .abandoned && saved.overallRPE == nil)
        #expect(saved.sets.count == 3 && saved.durationMinutes == 55 && saved.tonnageKg == 1_082.5)
        #expect(try await fixture.workouts.session(id: live.id) == saved)
        #expect(try await fixture.store.load() == nil)
        #expect(await fixture.activity.endCount == 1)
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func anEmptyAbandonWritesNothing() async throws {
        let live = Fix.session([Fix.bench([Fix.set(60, 12), Fix.set(70, 5)])])
        let service = try await fixture.resume(live)
        let abandoned = try await service.abandon(endedAt: ended)
        #expect(abandoned.id == live.id && abandoned.status == .abandoned && abandoned.sets.isEmpty)
        #expect(try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(try await fixture.store.load() == nil)
        #expect(await fixture.activity.endCount == 1)
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func anUnreadableSnapshotCanStillBeAbandoned() async throws {
        let snapshot = ActiveSessionSnapshot(startedAt: Fix.start, updatedAt: Fix.start, payload: Data("{\"formatVersion\":99}".utf8))
        try await fixture.store.save(snapshot)
        let service = fixture.makeService()
        let abandoned = try await service.abandon(endedAt: ended)
        #expect(abandoned.id == snapshot.id && abandoned.status == .abandoned && abandoned.sets.isEmpty)
        #expect(try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(try await fixture.store.load() == nil)
        #expect(await fixture.activity.endAllCalls == [nil])
        #expect(await fixture.notifier.cancelCount == 1)
    }

    @Test func abandonWithoutSnapshotThrows() async throws {
        let service = fixture.makeService()
        await #expect(throws: ActiveSessionError.noSession) { try await service.abandon(endedAt: ended) }
    }

    @Test func aForgottenSessionSuggestsTheLastSetPlusItsRest() async throws {
        // Dernière série validée à 8:40, repos 90 s, dernière action à 8:40.
        let service = try await fixture.resume(Fix.session([Fix.bench(Fix.benchSets())]))
        fixture.clock.set("2026-11-02T12:00")
        #expect(await service.suggestedEnd() == TestClock.date("2026-11-02T08:40").addingTimeInterval(90))
        fixture.clock.set("2026-11-02T09:30")
        #expect(await service.suggestedEnd() == nil)
        // Exactement 3 h ne suffit pas.
        fixture.clock.set("2026-11-02T11:40")
        #expect(await service.suggestedEnd() == nil)
    }

    @Test func aForgottenSessionWithoutValidatedSetsSuggestsNothing() async throws {
        let service = try await fixture.resume(Fix.session([Fix.bench([Fix.set(60, 12)])], lastActionAt: "2026-11-02T08:00"))
        fixture.clock.set("2026-11-02T12:00")
        #expect(await service.suggestedEnd() == nil)
    }

    @Test func discardAfterEraseEndsActivitiesAndTheRestWithoutWriting() async throws {
        let service = try await fixture.resume(benchSession())
        try await fixture.store.clear()
        await service.discardAfterErase()
        #expect(await fixture.activity.endAllCalls == [nil])
        #expect(await fixture.notifier.cancelCount == 1)
        #expect(try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture).isEmpty)
        #expect(try await fixture.store.load() == nil)
    }
}
