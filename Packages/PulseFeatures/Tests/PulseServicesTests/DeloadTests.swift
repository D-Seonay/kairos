import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct DeloadTests {
    private let calendar = TestClock.calendar

    private func profile(accepted: String? = nil, declined: String? = nil) -> UserProfile {
        UserProfile(onboardingCompletedAt: TestClock.date("2026-10-01T08:00"), deloadWeekStartedAt: accepted.map(TestClock.date),
                    deloadDeclinedAt: declined.map(TestClock.date))
    }

    /// Une séance de `minutes` minutes à RPE 6 chaque jour, `count` jours à partir de `start`.
    private func sessions(from start: String, count: Int, minutes: Double) -> [WorkoutSession] {
        (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: TestClock.date("\(start)T18:00")) else { return nil }
            return WorkoutSession(startedAt: date, kind: .strength, source: .pulse, status: .completed, title: "Séance",
                                  overallRPE: 6, durationMinutes: minutes, createdAt: date, updatedAt: date)
        }
    }

    @Test func theWindowRunsToTheNextSunday() {
        #expect(Deload.windowEnd(from: TestClock.date("2026-11-18T10:00"), calendar: calendar) == TestClock.date("2026-11-23T00:00"))
        #expect(Deload.windowEnd(from: TestClock.date("2026-11-22T10:00"), calendar: calendar) == TestClock.date("2026-11-30T00:00"),
                "Un dimanche, c'est le dimanche d'après")
    }

    @Test func theLatestDecisionWinsWhileItsWindowRuns() {
        let now = TestClock.date("2026-11-20T09:00")
        #expect(Deload.status(profile: profile(accepted: "2026-11-18T08:00"), now: now, calendar: calendar)
            == .active(since: TestClock.date("2026-11-18T08:00"), until: TestClock.date("2026-11-23T00:00")))
        #expect(Deload.status(profile: profile(declined: "2026-11-18T08:00"), now: now, calendar: calendar)
            == .declined(until: TestClock.date("2026-11-23T00:00")))
        #expect(Deload.status(profile: profile(accepted: "2026-11-10T08:00"), now: now, calendar: calendar) == .none)
        #expect(Deload.status(profile: profile(accepted: "2026-11-10T08:00", declined: "2026-11-19T08:00"), now: now,
                              calendar: calendar).isActive == false)
        #expect(Deload.status(profile: nil, now: now, calendar: calendar) == .none)
    }

    @Test func offeredWhenTheRatioStaysHighTwoDaysInARow() throws {
        // Trois semaines calmes de 30 min, puis huit jours de 120 min.
        let history = sessions(from: "2026-10-22", count: 21, minutes: 30) + sessions(from: "2026-11-12", count: 8, minutes: 120)
        let now = TestClock.date("2026-11-19T20:00")
        let offer = try #require(Deload.offer(sessions: history, profile: profile(), now: now, calendar: calendar))
        #expect(offer.ratio >= 1.5)
        #expect(Deload.offer(sessions: history, profile: profile(declined: "2026-11-18T08:00"), now: now, calendar: calendar) == nil)
        let oneDay = sessions(from: "2026-10-22", count: 28, minutes: 30) + sessions(from: "2026-11-19", count: 1, minutes: 900)
        #expect(Deload.offer(sessions: oneDay, profile: profile(), now: now, calendar: calendar) == nil, "Un seul jour au-dessus")
    }

    @Test func notOfferedWithoutTwentyEightDaysOfHistory() {
        let recent = UserProfile(onboardingCompletedAt: TestClock.date("2026-11-05T08:00"))
        let history = sessions(from: "2026-11-05", count: 7, minutes: 30) + sessions(from: "2026-11-12", count: 8, minutes: 120)
        #expect(Deload.offer(sessions: history, profile: recent, now: TestClock.date("2026-11-19T20:00"), calendar: calendar) == nil)
    }

    @Test func anActiveDeloadLightensTheLaunch() {
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 5), LiveFixtures.exercise(LiveFixtures.pecDeck,
                                                                                                             order: 1, sets: 5)])
        let launch = SessionLaunch.routine(day, programID: nil, recovery: LiveFixtures.recovery(.optimal), originalChosen: false,
                                           profile: LiveFixtures.profile(), deload: .active(since: .distantPast, until: .distantFuture))
        #expect(launch.day?.exercises.map(\.sets).reduce(0, +) == 6, "40 % de 10 séries en moins")
        #expect(launch.applied.first?.kind == .deload && !launch.policy.allowsIncrease && launch.loadFactor == 0.9)
        #expect(launch.plannedDay == day)

        let declined = SessionLaunch.routine(day, programID: nil, recovery: nil, originalChosen: false, profile: LiveFixtures.profile(),
                                             deload: .declined(until: .distantFuture))
        #expect(declined.day == day && declined.refused.map(\.kind) == [.deload] && declined.loadFactor == 1)
    }

    @Test func deloadLowersTheProposedLoadsByTenPercent() throws {
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 3)])
        let launch = SessionLaunch.routine(day, programID: nil, recovery: nil, originalChosen: false, profile: LiveFixtures.profile(),
                                           deload: .active(since: .distantPast, until: .distantFuture))
        let history = [LiveFixtures.done(LiveFixtures.bench, 100, 8), LiveFixtures.done(LiveFixtures.bench, 100, 8)]
        let session = LiveFixtures.session(launch, history: [LiveFixtures.bench: history])
        let weights = try #require(session.exercises.first).sets.map(\.proposed.weightKg)
        #expect(weights == [90, 90], "100 kg × 0,9, arrondi aux disques")
    }

    @Test func todaySessionShowsTheDeloadedDay() {
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 5)])
        let session = TodaySession(plannedDay: .strength(day), recovery: nil, deload: true)
        #expect(session.isDeload && session.isLightened && session.title == "Push, décharge")
        #expect(session.activeDay?.exercises.first?.sets == 3 && session.originalDay == day)
        let run = TodaySession(plannedDay: .run(RoutineDay(order: 0, name: "Endurance", kind: .run)), recovery: nil, deload: true)
        #expect(!run.isDeload)
    }

    @Test func deloadLoadsStartFromBeforeTheDeloadSoTheyDoNotCompound() async throws {
        let fixture = ActiveSessionFixture()
        let before = TestClock.date("2026-10-26T08:00")
        let during = TestClock.date("2026-10-30T08:00")
        for (date, weight) in [(before, 100.0), (during, 90.0)] {
            try await fixture.workouts.save(WorkoutSession(
                startedAt: date, kind: .strength, source: .pulse, status: .completed, title: "Push",
                sets: [LiveFixtures.done(LiveFixtures.bench, weight, 8)], createdAt: date, updatedAt: date))
        }
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 3)])
        let launch = SessionLaunch.routine(day, programID: nil, recovery: nil, originalChosen: false, profile: LiveFixtures.profile(),
                                           deload: .active(since: TestClock.date("2026-10-29T08:00"), until: .distantFuture))
        #expect(launch.historyLimit == TestClock.date("2026-10-29T08:00"))
        let session = try await fixture.makeService().start(launch)
        #expect(session.exercises.first?.sets.map(\.proposed.weightKg) == [90, 90],
                "3 séries moins 40 %, à 100 kg d'avant la décharge × 0,9, pas 81")
    }

    /// Le pec deck : 50 kg avant la décharge, 40 pendant. Ajouté ou remplaçant, il part de 50 kg baissés de 10 %, même
    /// après une relance : ni 40 (la dernière séance, sans baisse), ni 36 (baissé deux fois).
    @Test func addedAndReplacingExercisesTakeTheDeloadLoads() async throws {
        let fixture = ActiveSessionFixture()
        let before = TestClock.date("2026-10-26T08:00")
        let during = TestClock.date("2026-10-30T08:00")
        for (date, weight) in [(before, 50.0), (during, 40.0)] {
            try await fixture.workouts.save(WorkoutSession(
                startedAt: date, kind: .strength, source: .pulse, status: .completed, title: "Push",
                sets: (0..<3).map { _ in LiveFixtures.done(LiveFixtures.pecDeck, weight, 12) }, createdAt: date, updatedAt: date))
        }
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 3)])
        let launch = SessionLaunch.routine(day, programID: nil, recovery: nil, originalChosen: false, profile: LiveFixtures.profile(),
                                           deload: .active(since: TestClock.date("2026-10-29T08:00"), until: .distantFuture))
        let started = try await fixture.makeService().start(launch)
        #expect(started.addedLoadFactor == 0.9 && started.proposalHistoryLimit == TestClock.date("2026-10-29T08:00"))

        let relaunched = fixture.makeService()
        let added = try await relaunched.newExercises([LiveFixtures.pecDeck])
        #expect(added.first?.sets.map(\.proposed.weightKg) == [45, 45, 45], "50 kg d'avant la décharge × 0,9")
        let bench = try #require(started.exercises.first)
        let replacing = try await relaunched.replacement(for: bench.id, with: LiveFixtures.pecDeck, reason: .machineBusy)
        #expect(replacing?.sets.filter { $0.setType != .warmup }.map(\.proposed.weightKg) == [45, 45])
    }

    /// Rien de fait pendant la décharge : l'exercice ajouté part de 50 kg, baissés de 10 %.
    @Test func anExerciseAddedEarlyInTheDeloadIsLowered() async throws {
        let fixture = ActiveSessionFixture()
        try await fixture.seedHistory((0..<3).map { _ in LiveFixtures.done(LiveFixtures.pecDeck, 50, 12) })
        let launch = SessionLaunch.routine(LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench)]), programID: nil,
                                           recovery: nil, originalChosen: false, profile: LiveFixtures.profile(),
                                           deload: .active(since: TestClock.date("2026-10-29T08:00"), until: .distantFuture))
        _ = try await fixture.makeService().start(launch)
        let added = try await fixture.makeService().newExercises([LiveFixtures.pecDeck])
        #expect(added.first?.sets.map(\.proposed.weightKg) == [45, 45, 45], "50 kg × 0,9")
    }

    @Test func outsideADeloadAddedExercisesKeepTheirLoads() async throws {
        let fixture = ActiveSessionFixture()
        try await fixture.seedHistory((0..<3).map { _ in LiveFixtures.done(LiveFixtures.pecDeck, 50, 12) })
        let launch = SessionLaunch.routine(LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench)]), programID: nil,
                                           recovery: nil, originalChosen: false, profile: LiveFixtures.profile())
        let started = try await fixture.makeService().start(launch)
        #expect(started.loadFactor == nil && started.deloadStartedAt == nil)
        let added = try await fixture.makeService().newExercises([LiveFixtures.pecDeck])
        #expect(added.first?.sets.allSatisfy { ($0.proposed.weightKg ?? 0) >= 50 } == true)
    }
}
