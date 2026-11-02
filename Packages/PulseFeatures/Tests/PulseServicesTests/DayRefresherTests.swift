import Foundation
import PulseDomain
import PulseServices
import Testing

enum RefreshTestFailure: Error {
    case notScored(TodayScore?)
    case notNeedingCheckIn(TodayScore?)
}

struct DayRefresherTests {
    private let day = TestClock.date("2026-11-02T00:00")

    private func recovery(_ refresh: DayRefresh) throws -> DailyRecovery {
        guard case .scored(let recovery)? = refresh.score else { throw RefreshTestFailure.notScored(refresh.score) }
        return recovery
    }

    private func expectNeedsCheckIn(_ refresh: DayRefresh) throws {
        guard case .needsCheckIn? = refresh.score else { throw RefreshTestFailure.notNeedingCheckIn(refresh.score) }
    }

    @Test func foregroundRefreshScoresPlansAndPublishes() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        try await fixture.adopt()

        let refresh = await fixture.refresher.refresh(origin: .foreground)

        let scored = try recovery(refresh)
        #expect(scored.category == .optimal)
        #expect(scored.isEstimated == false)
        #expect(refresh.plannedDay.routineDay?.name == "Push")
        #expect(refresh.session.title == "Push")
        #expect(refresh.session.isLightened == false)
        #expect(refresh.profile?.onboardingCompletedAt != nil)
        #expect(refresh.nights.isEmpty == false)
        #expect(refresh.readAt == fixture.clock.now)
        #expect(refresh.checkIn == nil)

        let published = await fixture.widgets.published
        #expect(published == [WidgetSnapshot(day: day, score: Int(scored.score.rounded()), category: .optimal,
                                             isEstimated: false, sessionTitle: "Push", isLightened: false)])
        #expect(fixture.activity.lastOpenedAt() == fixture.clock.now)
        #expect(await fixture.notifications.cancelCount == 1)
        #expect(await fixture.notifications.scheduled.isEmpty)
    }

    @Test func backgroundRefreshNotifiesOnce() async throws {
        let fixture = RefresherFixture(scenario: .badNight, at: "2026-11-02T07:30")
        try await fixture.adopt()

        _ = await fixture.refresher.refresh(origin: .background)
        let first = await fixture.notifications.scheduled
        #expect(first.count == 1)
        #expect(first.first?.title == "Ton score du matin est prêt")
        #expect(first.first?.body.hasSuffix(" · fatigue modérée, séance allégée") == true)
        #expect(fixture.activity.lastNotifiedDay() == day)

        _ = await fixture.refresher.refresh(origin: .background)
        #expect(await fixture.notifications.scheduled == first)
        #expect(await fixture.widgets.published.count == 2)
        #expect(await fixture.notifications.cancelCount == 0)
        #expect(fixture.activity.lastOpenedAt() == nil)
    }

    /// La planification est suspendue : sans file, les trois passages arriveraient devant la porte avant que le premier ait noté le jour.
    @Test func concurrentBackgroundRefreshesNotifyOnce() async throws {
        let gate = Gate()
        let fixture = RefresherFixture(scenario: .badNight, at: "2026-11-02T07:30", holdingNotificationsAt: gate)
        try await fixture.adopt()

        async let first = fixture.refresher.refresh(origin: .background)
        async let second = fixture.refresher.refresh(origin: .background)
        async let third = fixture.refresher.refresh(origin: .background)
        await gate.waitForArrival()
        try await Task.sleep(for: .milliseconds(100))
        await gate.open()
        let results = await [first, second, third]

        #expect(await fixture.notifications.scheduled.count == 1)
        #expect(await fixture.widgets.published.count == 3)
        #expect(Set(try results.map { try recovery($0).score }).count == 1)
    }

    @Test func openedAppSilencesTheBackground() async throws {
        let fixture = RefresherFixture(scenario: .badNight, at: "2026-11-02T07:00")
        try await fixture.adopt()

        _ = await fixture.refresher.refresh(origin: .foreground)
        fixture.clock.set("2026-11-02T07:30")
        _ = await fixture.refresher.refresh(origin: .background)

        #expect(await fixture.notifications.scheduled.isEmpty)
        #expect(await fixture.widgets.published.count == 2)
    }

    @Test func backgroundBeforeOnboardingDoesNothing() async {
        let fixture = RefresherFixture(scenario: .goodNight)

        let refresh = await fixture.refresher.refresh(origin: .background)

        #expect(refresh.profile == nil)
        #expect(refresh.score == nil)
        #expect(refresh.nights.isEmpty)
        #expect(await fixture.source.changeCalls == 0)
        #expect(await fixture.widgets.published.isEmpty)
        #expect(await fixture.notifications.scheduled.isEmpty)
        #expect(await fixture.notifications.cancelCount == 0)
    }

    @Test func backgroundBeforeTheOnboardingEndsDoesNothing() async throws {
        let fixture = RefresherFixture(scenario: .goodNight)
        try await fixture.adopt(onboarded: false)

        let refresh = await fixture.refresher.refresh(origin: .background)

        #expect(refresh.profile?.onboardingCompletedAt == nil)
        #expect(refresh.score == nil)
        #expect(await fixture.source.changeCalls == 0)
        #expect(await fixture.widgets.published.isEmpty)
        #expect(try await fixture.score(on: "2026-11-02T00:00") == nil)
    }

    @Test func backgroundRefreshWithUnreadableHealthKeepsTheScore() async throws {
        let fixture = RefresherFixture(scenario: .goodNight, at: "2026-11-02T07:00")
        try await fixture.adopt()
        let early = try recovery(await fixture.refresher.refresh(origin: .foreground))

        await fixture.source.setFails(true)
        fixture.clock.set("2026-11-02T08:00")
        let later = await fixture.refresher.refresh(origin: .background)

        #expect(try recovery(later) == early)
        #expect(later.readAt == nil)
        #expect(later.nights.isEmpty == false)
        #expect(await fixture.widgets.published.count == 2)
    }

    @Test func choosingTheOriginalRepublishesAsNormal() async throws {
        let fixture = RefresherFixture(scenario: .badNight)
        try await fixture.adopt()
        _ = await fixture.refresher.refresh(origin: .foreground)
        #expect(await fixture.widgets.published.last?.isLightened == true)

        let chosen = try await fixture.refresher.chooseOriginalSession(true)

        #expect(chosen.originalSessionChosen == true)
        #expect(await fixture.widgets.published.count == 2)
        #expect(await fixture.widgets.published.last?.isLightened == false)
        #expect(await fixture.widgets.published.last?.sessionTitle == "Push")
        #expect(try await fixture.score(on: "2026-11-02T00:00")?.originalSessionChosen == true)
    }

    @Test func checkInPublishesAnEstimatedSnapshot() async throws {
        let fixture = RefresherFixture(scenario: .threeNights)
        try await fixture.adopt()
        let first = await fixture.refresher.refresh(origin: .foreground)
        try expectNeedsCheckIn(first)

        let estimated = try await fixture.refresher.saveCheckIn(CheckInAnswers(sleep: 3, pain: 3, motivation: 3))

        #expect(estimated.isEstimated)
        #expect(await fixture.widgets.published.last?.isEstimated == true)
        #expect(await fixture.widgets.published.last?.score == Int(estimated.score.rounded()))

        let next = await fixture.refresher.refresh(origin: .foreground)
        #expect(try recovery(next) == estimated)
        #expect(next.checkIn?.day == day)
        #expect(next.checkIn?.answers == CheckInAnswers(sleep: 3, pain: 3, motivation: 3))
    }

    @Test func noScoreNoSnapshot() async throws {
        let fixture = RefresherFixture(scenario: .noData)
        try await fixture.adopt()

        let refresh = await fixture.refresher.refresh(origin: .foreground)

        try expectNeedsCheckIn(refresh)
        #expect(refresh.checkIn == nil)
        #expect(await fixture.widgets.published.isEmpty)
        #expect(await fixture.notifications.scheduled.isEmpty)
    }

    @Test func choosingTheOriginalWithoutAScoreIsRefused() async throws {
        let fixture = RefresherFixture(scenario: .noData)
        try await fixture.adopt()

        await #expect(throws: DailyScoreError.noScoreToday) {
            try await fixture.refresher.chooseOriginalSession(true)
        }
        #expect(await fixture.widgets.published.isEmpty)
    }
}
