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
            == .active(until: TestClock.date("2026-11-23T00:00")))
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
                                           profile: LiveFixtures.profile(), deload: .active(until: .distantFuture))
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
                                           deload: .active(until: .distantFuture))
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
}
