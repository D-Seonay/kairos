import Foundation
import PulseDomain
import PulseServices
import Testing

/// La saisie d'une séance passée (spec M4 §19.4) : l'historique d'avant sa date, ni repos ni notification ni Live Activity,
/// des heures de série dans la séance, et l'abandon qui annule la saisie.
struct ActiveSessionPastTests {
    private let fixture = ActiveSessionFixture()
    /// Le mercredi 28 octobre 2026 de 18 h à 19 h 05, saisi le 2 novembre.
    private let interval = DateInterval(start: TestClock.date("2026-10-28T18:00"), end: TestClock.date("2026-10-28T19:05"))

    private var pastLaunch: SessionLaunch {
        SessionLaunch.past(LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, order: 0, rpe: 8, rest: 120)]),
                           programID: UUID(), interval: interval)
    }

    /// L'historique du bench le 26 octobre (60 × 12, 70 × 5, 70 × 5), puis une séance plus lourde le 30, après la date saisie.
    private func seedHistoryAroundTheDate() async throws {
        try await fixture.seedHistory(LiveFixtures.rampingBench)
        let later = TestClock.date("2026-10-30T08:00")
        try await fixture.workouts.save(WorkoutSession(
            startedAt: later, kind: .strength, source: .pulse, status: .completed, title: "Push",
            sets: [LiveFixtures.done(LiveFixtures.bench, 90, 3)], createdAt: later, updatedAt: later))
    }

    @Test func aPastSessionReadsTheHistoryBeforeItsDateAndStartsNothing() async throws {
        try await seedHistoryAroundTheDate()
        let session = try await fixture.makeService().start(pastLaunch)
        #expect(session.isPastEntry && session.startedAt == interval.start && session.pastEndedAt == interval.end)
        #expect(session.title == "Push" && session.routineDayID != nil)
        // Les charges viennent du 26 octobre, pas du 90 × 3 du 30.
        #expect(session.exercises[0].lastTimeText?.contains("70") == true)
        #expect(session.exercises[0].sets.compactMap(\.proposed.weightKg).allSatisfy { $0 < 80 })
        #expect(await fixture.activity.states.isEmpty)
    }

    @Test func validatingAPastSetStartsNoRestNotificationOrActivity() async throws {
        try await seedHistoryAroundTheDate()
        let service = fixture.makeService()
        let session = try await service.start(pastLaunch)
        let exercise = session.exercises[0]
        let validated = try await service.apply(.validate(exercise: exercise.id, set: exercise.sets[0].id))
        #expect(validated.rest == nil && validated.exercises[0].sets[0].completedAt != nil)
        #expect(await fixture.notifier.scheduled.isEmpty)
        #expect(await fixture.activity.states.isEmpty)
        #expect(await service.suggestedEnd() == nil)
    }

    @Test func finishingSavesTheSessionOnItsDateWithSetsSpreadOverIt() async throws {
        try await seedHistoryAroundTheDate()
        let service = fixture.makeService()
        let session = try await service.start(pastLaunch)
        let exercise = session.exercises[0]
        _ = try await service.apply(.edit(exercise: exercise.id, set: exercise.sets[0].id, weightKg: .some(75), reps: .some(5)))
        for (index, set) in exercise.sets.enumerated() {
            fixture.clock.set("2026-11-02T08:0\(index + 1)")
            _ = try await service.apply(.validate(exercise: exercise.id, set: set.id))
        }
        let recap = try await service.recap(endedAt: interval.end)
        #expect(recap.durationMinutes == 65 && recap.workingSets == 3)
        // 75 × 5 bat le 70 × 5 du 26 octobre ; le 90 × 3 du 30, plus tard, ne compte pas.
        #expect(recap.beatenRecords.contains { $0.kind == .maxWeight })

        let saved = try await service.finish(overallRPE: 8, note: nil, endedAt: interval.end)
        #expect(saved.status == .completed && saved.source == .pulse)
        #expect(saved.startedAt == interval.start && saved.endedAt == interval.end && saved.durationMinutes == 65)
        let times = saved.sets.compactMap(\.completedAt)
        #expect(times.count == 3 && times == times.sorted())
        #expect(times.allSatisfy { interval.contains($0) } && times.last == interval.end)
        #expect(try await fixture.workouts.lastSets(for: LiveFixtures.bench).map(\.actualWeightKg) == [90])
        #expect(try await fixture.store.load() == nil)
    }

    @Test func abandoningAPastSessionSavesNothing() async throws {
        try await seedHistoryAroundTheDate()
        let service = fixture.makeService()
        let session = try await service.start(pastLaunch)
        let exercise = session.exercises[0]
        _ = try await service.apply(.validate(exercise: exercise.id, set: exercise.sets[0].id))
        _ = try await service.abandon(endedAt: interval.end)
        let all = try await fixture.workouts.sessions(from: .distantPast, to: .distantFuture)
        #expect(!all.contains { $0.id == session.id })
        #expect(try await fixture.store.load() == nil)
    }

    @Test func thePastSessionsServiceLeavesTheLiveSnapshotAlone() async throws {
        let (_, live) = try await fixture.startPush()
        let records = RecordsService(workouts: fixture.workouts, records: InMemoryPersonalRecordRepository(),
                                     userExercises: fixture.userExercises, library: .bundled, now: { .t0 })
        let clock = fixture.clock
        let past = ActiveSessionService.pastSessions(
            workouts: fixture.workouts, profiles: fixture.profiles, settings: fixture.settings,
            userExercises: fixture.userExercises, records: records, library: .bundled, calendar: TestClock.calendar,
            now: { clock.now })
        let entry = try await past.start(pastLaunch)
        _ = try await past.finish(overallRPE: 7, note: nil, endedAt: interval.end)
        #expect(try await fixture.stored()?.id == live.id)
        #expect(try await fixture.workouts.session(id: entry.id) != nil)
    }

    @Test func aPastLaunchWithoutRoutineIsAnEmptySession() {
        let launch = SessionLaunch.past(nil, programID: UUID(), interval: interval)
        #expect(launch.day == nil && launch.programID == nil && launch.past == interval)
        #expect(launch.title == "Séance libre" && launch.policy.allowsIncrease)
    }
}
