import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct MorningNotificationRuleTests {
    private let calendar = TestClock.calendar
    private let morning = TestClock.date("2026-11-02T07:30")

    private func recovery(_ score: Double = 58.4, _ category: RecoveryCategory = .moderateFatigue,
                          day: String = "2026-11-02T00:00", estimated: Bool = false) -> DailyRecovery {
        DailyRecovery(day: TestClock.date(day), score: score, category: category, isEstimated: estimated,
                      calibration: .ready, createdAt: morning, updatedAt: morning)
    }

    private func session(_ recovery: DailyRecovery) throws -> TodaySession {
        let template = try #require(ContentLibrary.bundled.programTemplate(id: "ppl-3"))
        let program = ProgramAdopter(library: .bundled).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: morning)
        return TodaySession(plannedDay: TodayPlanner.plan(program: program, on: morning, calendar: calendar), recovery: recovery)
    }

    private func message(_ recovery: DailyRecovery, profile: UserProfile = UserProfile(), lastOpenedAt: Date? = nil,
                         lastNotifiedDay: Date? = nil, now: String = "2026-11-02T07:30") throws -> MorningScoreMessage? {
        MorningNotificationRule.message(recovery: recovery, session: try session(recovery), profile: profile,
                                        lastOpenedAt: lastOpenedAt, lastNotifiedDay: lastNotifiedDay,
                                        now: TestClock.date(now), calendar: calendar)
    }

    @Test func measuredMorningScoreGivesTheMessage() throws {
        let result = try #require(try message(recovery()))
        #expect(result.title == "Ton score du matin est prêt")
        #expect(result.body == "58 · fatigue modérée, séance allégée")
    }

    @Test func normalSessionHasNoSuffix() throws {
        let result = try #require(try message(recovery(72, .normal)))
        #expect(result.body == "72 · forme normale")
    }

    @Test func estimatedScoreIsNotAnnounced() throws {
        #expect(try message(recovery(estimated: true)) == nil)
    }

    @Test func disabledPreferenceIsRespected() throws {
        #expect(try message(recovery(), profile: UserProfile(morningScoreNotification: false)) == nil)
    }

    @Test func deadlineDefaultsToTen() throws {
        #expect(try message(recovery(), now: "2026-11-02T09:59") != nil)
        #expect(try message(recovery(), now: "2026-11-02T10:00") == nil)
        #expect(MorningNotificationRule.defaultDeadlineMinutes == 600)
    }

    @Test func customDeadline() throws {
        let profile = UserProfile(morningScoreDeadlineMinutes: 450)
        #expect(try message(recovery(), profile: profile, now: "2026-11-02T07:29") != nil)
        #expect(try message(recovery(), profile: profile, now: "2026-11-02T07:30") == nil)
    }

    @Test func openingAfterFourSilencesIt() throws {
        #expect(try message(recovery(), lastOpenedAt: TestClock.date("2026-11-02T07:00")) == nil)
        #expect(try message(recovery(), lastOpenedAt: TestClock.date("2026-11-02T02:00")) != nil)
        #expect(try message(recovery(), lastOpenedAt: TestClock.date("2026-11-01T22:00")) != nil)
    }

    @Test func oncePerDay() throws {
        #expect(try message(recovery(), lastNotifiedDay: TestClock.date("2026-11-02T00:00")) == nil)
        #expect(try message(recovery(), lastNotifiedDay: TestClock.date("2026-11-01T00:00")) != nil)
    }

    @Test func yesterdaysScoreIsNotAnnounced() throws {
        #expect(try message(recovery(day: "2026-11-01T00:00")) == nil)
    }
}
