import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct WidgetSnapshotTests {
    private let now = TestClock.date("2026-11-02T07:30")

    private func recovery(_ score: Double, _ category: RecoveryCategory = .moderateFatigue) -> DailyRecovery {
        DailyRecovery(day: TestClock.date("2026-11-02T00:00"), score: score, category: category, isEstimated: false,
                      sdnnMs: 41, restingHeartRate: 58, asleepMinutes: 400,
                      calibration: .ready, createdAt: now, updatedAt: now)
    }

    private func session(_ recovery: DailyRecovery) throws -> TodaySession {
        let template = try #require(ContentLibrary.bundled.programTemplate(id: "ppl-3"))
        let program = ProgramAdopter(library: .bundled).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        let planned = TodayPlanner.plan(program: program, on: now, calendar: TestClock.calendar)
        return TodaySession(plannedDay: planned, recovery: recovery)
    }

    @Test func snapshotCarriesNoRawValue() throws {
        let fatigue = recovery(58.4)
        let data = try JSONEncoder().encode(WidgetSnapshot(recovery: fatigue, session: try session(fatigue)))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["day", "score", "category", "isEstimated", "sessionTitle", "isLightened"])
    }

    @Test func snapshotRoundsTheScore() throws {
        let low = recovery(58.4)
        let high = recovery(64.5, .normal)
        #expect(WidgetSnapshot(recovery: low, session: try session(low)).score == 58)
        #expect(WidgetSnapshot(recovery: high, session: try session(high)).score == 65)
    }

    @Test func snapshotCarriesTheSession() throws {
        let fatigue = recovery(58.4)
        let snapshot = WidgetSnapshot(recovery: fatigue, session: try session(fatigue))
        #expect(snapshot.sessionTitle == "Push, volume allégé")
        #expect(snapshot.isLightened)
        #expect(snapshot.category == .moderateFatigue)
    }

    @Test func sentenceNames() {
        #expect(RecoveryCategory.optimal.sentenceName == "forme optimale")
        #expect(RecoveryCategory.normal.sentenceName == "forme normale")
        #expect(RecoveryCategory.moderateFatigue.sentenceName == "fatigue modérée")
        #expect(RecoveryCategory.overreached.sentenceName == "surmenage")
    }
}
