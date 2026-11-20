import Foundation
import PulseDomain
import PulseServices
import Testing

struct DayRefresherPlanningTests {
    @Test func theSnapshotCarriesTheStreakTheWeekAndTheNextSession() async throws {
        let fixture = RefresherFixture(scenario: .goodNight, planning: true)
        try await fixture.adopt()
        _ = await fixture.refresher.refresh(origin: .foreground)

        let snapshot = try #require(await fixture.widgets.published.last)
        #expect(snapshot.week?.count == 7 && snapshot.week?.first?.isToday == true && snapshot.week?.first?.kind == .strength)
        #expect(snapshot.streak == WidgetStreak(weeks: 0, completed: 0, target: 3))
        let next = try #require(snapshot.nextSession)
        #expect(next.kind == .strength && next.date > TestClock.date("2026-11-02T23:59"))
        #expect(snapshot.loadRatio == nil, "Pas encore 28 jours d'historique")
    }

    @Test func thePassAppliesTheRulesBeforePlanningTheDay() async throws {
        let fixture = RefresherFixture(scenario: .goodNight, at: "2026-11-05T08:00", planning: true)
        try await fixture.programs.save(RuleFixtures.program())
        try await fixture.profiles.save(UserProfile(restWeekdays: [.sunday], onboardingCompletedAt: RuleFixtures.created,
                                                    activeProgramID: RuleFixtures.programID))
        try await fixture.workouts.save(RuleFixtures.session("2026-11-04T18:00", exercises: ["back-squat-barbell", "leg-press-machine"]))
        let refresh = await fixture.refresher.refresh(origin: .foreground)

        guard case .rest = refresh.plannedDay else {
            Issue.record("Le fractionné du jeudi, au lendemain des jambes faites, doit partir : \(refresh.plannedDay)")
            return
        }
        let lines = try await fixture.scheduled.days(from: .distantPast, to: .distantFuture)
        #expect(lines.map(\.date) == [TestClock.date("2026-11-05T00:00"), TestClock.date("2026-11-07T00:00")])
    }

    @Test func acceptingTheDeloadLightensTheNextPass() async throws {
        let fixture = RefresherFixture(scenario: .goodNight, planning: true)
        try await fixture.adopt()
        try await fixture.refresher.decideDeload(true)
        #expect(try await fixture.profiles.load()?.deloadWeekStartedAt == fixture.clock.now)

        let refresh = await fixture.refresher.refresh(origin: .foreground)
        #expect(refresh.session.isDeload && refresh.session.title == "Push, décharge")
        #expect(try #require(await fixture.widgets.published.last).isLightened)
    }

    @Test func decliningTheDeloadIsRemembered() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        try await fixture.adopt()
        try await fixture.refresher.decideDeload(false)
        let profile = try #require(try await fixture.profiles.load())
        #expect(profile.deloadDeclinedAt == fixture.clock.now && profile.deloadWeekStartedAt == nil)
        #expect(!(await fixture.refresher.refresh(origin: .foreground)).session.isDeload)
    }
}
