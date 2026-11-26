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

    /// La proposition sur `sessions` (tout l'historique), le début de l'historique lu comme l'accueil le lit.
    private func offer(_ sessions: [WorkoutSession], profile: UserProfile, now: String = "2026-11-19T20:00") -> DeloadOffer? {
        let start = TrainingLoad.historyStart(sessions: sessions, onboardingCompletedAt: profile.onboardingCompletedAt)
        return Deload.offer(sessions: sessions, historyStart: start, profile: profile, now: TestClock.date(now), calendar: calendar)
    }

    @Test func offeredWhenTheRatioStaysHighTwoDaysInARow() throws {
        // Trois semaines calmes de 30 min, puis huit jours de 120 min.
        let history = sessions(from: "2026-10-22", count: 21, minutes: 30) + sessions(from: "2026-11-12", count: 8, minutes: 120)
        let offer = try #require(offer(history, profile: profile()))
        #expect(offer.ratio >= 1.5)
        #expect(self.offer(history, profile: profile(declined: "2026-11-18T08:00")) == nil)
        let oneDay = sessions(from: "2026-10-22", count: 28, minutes: 30) + sessions(from: "2026-11-19", count: 1, minutes: 900)
        #expect(self.offer(oneDay, profile: profile()) == nil, "Un seul jour au-dessus")
    }

    @Test func notOfferedWithoutTwentyEightDaysOfHistory() {
        let recent = UserProfile(onboardingCompletedAt: TestClock.date("2026-11-05T08:00"))
        let history = sessions(from: "2026-11-05", count: 7, minutes: 30) + sessions(from: "2026-11-12", count: 8, minutes: 120)
        #expect(offer(history, profile: recent) == nil)
    }

    /// Trois semaines sans séance, puis une semaine normale : le ratio vaut 4 hier et aujourd'hui, mais les deux semaines
    /// d'avant la semaine aiguë n'ont pas trois séances. C'est une reprise, pas une surcharge : rien n'est proposé.
    @Test func notOfferedWhenComingBackFromABreak() throws {
        let before = sessions(from: "2026-09-01", count: 30, minutes: 60)
        let comeback = sessions(from: "2026-11-13", count: 7, minutes: 60)
        let start = TrainingLoad.historyStart(sessions: before + comeback, onboardingCompletedAt: profile().onboardingCompletedAt)
        let ratio = try #require(TrainingLoad.acwr(sessions: before + comeback, historyStart: start,
                                                   now: TestClock.date("2026-11-19T20:00"), calendar: calendar))
        #expect(ratio.ratio == 4, "Le ratio reste affiché tel quel")
        #expect(offer(before + comeback, profile: profile()) == nil)
        // Une semaine pleine, deux semaines de pause, puis la reprise : le ratio vaut 2, et rien n'est proposé non plus.
        let weekBeforeTheBreak = sessions(from: "2026-10-23", count: 7, minutes: 60)
        #expect(offer(before + weekBeforeTheBreak + comeback, profile: profile()) == nil)
        // Deux séances seulement dans les deux semaines d'avant : toujours pas de base.
        let twoBefore = sessions(from: "2026-11-05", count: 2, minutes: 60)
        #expect(offer(before + twoBefore + comeback, profile: profile()) == nil)
        // Trois séances : la base existe, la surcharge est réelle.
        let threeBefore = sessions(from: "2026-11-05", count: 3, minutes: 60)
        #expect(offer(before + threeBefore + comeback, profile: profile()) != nil)
    }

    /// Un nouvel utilisateur dont Apple Santé apporte des courses d'avant Pulse : sa charge chronique ne tient que d'elles,
    /// son historique commence à la fin de l'onboarding. Rien n'est proposé avant 28 jours.
    @Test func notOfferedToANewUserWhoseHistoryIsOnlyImportedRuns() {
        let recent = UserProfile(onboardingCompletedAt: TestClock.date("2026-11-10T08:00"))
        let runs = sessions(from: "2026-09-20", count: 50, minutes: 20).map { run -> WorkoutSession in
            var run = run
            run.kind = .run
            run.source = .appleHealth
            return run
        }
        let strength = sessions(from: "2026-11-10", count: 10, minutes: 90)
        #expect(offer(runs + strength, profile: recent) == nil)
        let later = UserProfile(onboardingCompletedAt: TestClock.date("2026-10-20T08:00"))
        #expect(offer(runs + strength, profile: later) != nil, "Avec 28 jours d'historique, la proposition revient")
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

    /// 100 kg × 8 avant la décharge, 90 kg × 8 pendant : la séance normale d'après repart de 100 kg, pas de 90.
    @Test func afterADeloadLoadsRestartFromBeforeTheDeload() async throws {
        let fixture = ActiveSessionFixture()
        let before = TestClock.date("2026-10-20T08:00")
        let during = TestClock.date("2026-10-27T08:00")
        for (date, weight, applied) in [(before, 100.0, [SessionAdjustment]()), (during, 90.0, [DeloadAdjuster.adjustment])] {
            try await fixture.workouts.save(WorkoutSession(
                startedAt: date, kind: .strength, source: .pulse, status: .completed, title: "Push", appliedAdjustments: applied,
                sets: (0..<3).map { LiveFixtures.done(LiveFixtures.bench, weight, 8, order: $0) }, createdAt: date, updatedAt: date))
        }
        let day = LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, sets: 3)])
        let launch = SessionLaunch.routine(day, programID: nil, recovery: nil, originalChosen: false, profile: LiveFixtures.profile())
        #expect(launch.historyLimit == nil && launch.loadFactor == 1)
        let service = fixture.makeService()
        let session = try await service.start(launch)
        #expect(session.exercises.first?.sets.map(\.proposed.weightKg) == [100, 100, 100], "100 kg d'avant la décharge, pas 90")
        let added = try await service.newExercises([LiveFixtures.bench])
        #expect(added.first?.sets.map(\.proposed.weightKg) == [100, 100, 100], "Un exercice ajouté suit la même référence")
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
