import Foundation
import PulseDomain
@testable import PulseServices
import Testing

struct WidgetPlanningTests {
    private typealias Fixture = PlanningFixtures
    private let calendar = TestClock.calendar

    private func overview(now: String, sessions: [WorkoutSession] = []) -> PlanningOverview {
        let date = TestClock.date(now)
        let context = ScheduleContext(program: Fixture.program(), sessions: sessions, restWeekdays: [.sunday], calendar: calendar)
        let days = WeekSchedule.days(weekStart: WeekSchedule.weekStart(of: date, calendar: calendar), context: context, now: date)
        let streak = WeekStreak.summary(sessions: sessions, target: 5, historyStart: Fixture.created, now: date, calendar: calendar)
        return PlanningOverview(profile: nil, program: Fixture.program(), days: days, streak: streak, hasUserMoves: false,
                                historyStart: Fixture.created)
    }

    @Test func mapsTheWeekAndTheStreak() {
        let now = "2026-11-18T12:00"
        let planning = WidgetPlanning.make(overview: overview(now: now, sessions: [Fixture.session("2026-11-16T18:00")]),
                                           loadRatio: 1.2, now: TestClock.date(now), calendar: calendar)
        #expect(planning.week.map(\.state) == [.done, .missed, .planned, .planned, .planned, .rest, .rest])
        #expect(planning.week.map(\.kind) == [.strength, .strength, .strength, .run, .strength, .rest, .rest])
        #expect(planning.week[2].isToday)
        #expect(planning.streak == WidgetStreak(weeks: 0, completed: 1, target: 5))
        #expect(planning.loadRatio == 1.2)
        #expect(planning.nextSession?.title == "Endurance" && planning.nextSession?.detail == "Sortie facile · 45 min")
    }

    @Test func strengthDetailAgreesInNumber() {
        #expect(WidgetPlanning.strengthDetail(exercises: 5, sets: 16) == "5 exercices · 16 séries")
        #expect(WidgetPlanning.strengthDetail(exercises: 1, sets: 1) == "1 exercice · 1 série")
        #expect(WidgetPlanning.strengthDetail(exercises: 1, sets: 3) == "1 exercice · 3 séries")
    }

    @Test func theNextSessionCanFallInTheNextWeek() {
        let now = "2026-11-21T12:00"
        let planning = WidgetPlanning.make(overview: overview(now: now), loadRatio: nil, now: TestClock.date(now), calendar: calendar)
        #expect(planning.nextSession?.date == TestClock.date("2026-11-23T00:00") && planning.nextSession?.title == "Push")
    }

    @Test func anOldSnapshotStillDecodes() throws {
        let json = #"{"category":"normal","day":"2026-11-02T00:00:00Z","isEstimated":false,"isLightened":false,"score":72}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WidgetSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.score == 72 && snapshot.streak == nil && snapshot.week == nil)
    }
}
