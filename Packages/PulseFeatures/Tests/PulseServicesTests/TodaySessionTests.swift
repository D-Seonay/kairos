import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct TodaySessionTests {
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-02T07:30")

    private func program(_ templateID: String) throws -> Program {
        let template = try #require(ContentLibrary.bundled.programTemplate(id: templateID))
        return ProgramAdopter(library: .bundled).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
    }

    private func plan(_ templateID: String, on text: String) throws -> PlannedDay {
        TodayPlanner.plan(program: try program(templateID), on: TestClock.date(text), calendar: calendar)
    }

    private func recovery(_ score: Double, _ category: RecoveryCategory, originalChosen: Bool? = nil) -> DailyRecovery {
        DailyRecovery(day: TestClock.date("2026-11-02T00:00"), score: score, category: category, isEstimated: false,
                      calibration: .ready, originalSessionChosen: originalChosen, createdAt: now, updatedAt: now)
    }

    private func setCount(_ day: RoutineDay?) -> Int {
        day?.exercises.reduce(0) { $0 + $1.sets } ?? 0
    }

    @Test func noScoreMeansPlanned() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"), recovery: nil)
        #expect(session.status == .planned)
        #expect(session.adjusted == nil)
        #expect(session.activeDay == session.originalDay)
        #expect(session.activeDay?.name == "Push")
        #expect(session.title == "Push")
        #expect(!session.isLightened)
    }

    @Test func optimalScoreKeepsThePlannedSession() throws {
        let optimal = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"), recovery: recovery(94, .optimal))
        #expect(optimal.status == .planned)
        #expect(optimal.activeDay == optimal.originalDay)
        let restored = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"),
                                    recovery: recovery(94, .optimal, originalChosen: true))
        #expect(restored.status == .planned)
    }

    @Test func fatigueAdjustsAndLightens() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"), recovery: recovery(50, .moderateFatigue))
        #expect(session.status == .adjusted)
        #expect(setCount(session.activeDay) == 15)
        #expect(session.title == "Push, volume allégé")
        #expect(session.isLightened)
    }

    @Test func normalIsAdjustedNotLightened() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"), recovery: recovery(72, .normal))
        #expect(session.status == .adjusted)
        #expect(session.title == "Push")
        #expect(!session.isLightened)
    }

    @Test func restoredUsesTheOriginal() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"),
                                   recovery: recovery(50, .moderateFatigue, originalChosen: true))
        #expect(session.status == .restored)
        #expect(session.originalChosen)
        #expect(session.activeDay == session.originalDay)
        #expect(setCount(session.activeDay) == 19)
        #expect(session.title == "Push")
        #expect(!session.isLightened)
    }

    @Test func overreachedKeepsTheDayAndLightens() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T08:00"), recovery: recovery(30, .overreached))
        #expect(session.status == .adjusted)
        #expect(session.activeDay == session.originalDay)
        #expect(session.isLightened)
    }

    @Test func runTitleUsesTheRunType() throws {
        let planned = try plan("runner-strength", on: "2026-11-05T08:00")
        #expect(planned.routineDay?.runType == .intervals)
        #expect(TodaySession(plannedDay: planned, recovery: nil).title == "Fractionné")
    }

    @Test func restDayHasNoTitle() throws {
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-03T08:00"), recovery: recovery(72, .normal))
        #expect(session.title == nil)
        #expect(session.activeDay == nil)
        #expect(session.status == .planned)
    }

    @Test func noProgramHasNoTitle() {
        #expect(TodaySession(plannedDay: .noProgram, recovery: nil).title == nil)
    }
}
