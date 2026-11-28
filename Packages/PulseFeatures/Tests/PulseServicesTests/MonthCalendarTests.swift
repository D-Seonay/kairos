import Foundation
import PulseDomain
import PulseServices
import Testing

struct MonthCalendarTests {
    private typealias Fixture = PlanningFixtures
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-18T12:00")

    private func grid(sessions: [WorkoutSession] = [], overrides: [ScheduledDay] = []) -> MonthGrid {
        MonthCalendar.grid(month: now, context: ScheduleContext(program: Fixture.program(), overrides: overrides, sessions: sessions,
                                                                calendar: calendar), now: now)
    }

    private func day(_ grid: MonthGrid, _ text: String) -> MonthDay? {
        let date = TestClock.date("\(text)T00:00")
        return grid.weeks.joined().first { $0.date == date }
    }

    @Test func novemberRunsFromMondayOctober26ToSundayDecember6() {
        let result = grid()
        #expect(result.month == TestClock.date("2026-11-01T00:00"))
        #expect(result.weeks.count == 6 && result.weeks.allSatisfy { $0.count == 7 })
        #expect(result.weeks.first?.first?.date == TestClock.date("2026-10-26T00:00"))
        #expect(result.weeks.last?.last?.date == TestClock.date("2026-12-06T00:00"))
        #expect(day(result, "2026-10-31")?.isInMonth == false && day(result, "2026-11-01")?.isInMonth == true)
        #expect(day(result, "2026-11-18")?.isToday == true)
    }

    @Test func doneKindsAndMarks() {
        let result = grid(sessions: [
            Fixture.session("2026-11-10T07:00", kind: .run), Fixture.session("2026-11-10T18:00"),
            Fixture.session("2026-11-12T18:00", record: true), Fixture.session("2026-11-13T18:00"),
            Fixture.session("2026-11-14T18:00", status: .abandoned)
        ])
        #expect(day(result, "2026-11-10")?.done == [.strength, .run] && day(result, "2026-11-10")?.hasMark == true)
        #expect(day(result, "2026-11-12")?.hasMark == true)
        #expect(day(result, "2026-11-13")?.done == [.strength] && day(result, "2026-11-13")?.hasMark == false)
        #expect(day(result, "2026-11-14")?.done == [])
    }

    @Test func otherAppleHealthWorkoutsMarkTheirDay() {
        let context = ScheduleContext(program: Fixture.program(), calendar: calendar,
                                      activities: [TestClock.date("2026-11-11T07:30"), TestClock.date("2026-11-11T19:00")])
        let result = MonthCalendar.grid(month: now, context: context, now: now)
        #expect(day(result, "2026-11-11")?.hasActivity == true && day(result, "2026-11-11")?.done == [])
        #expect(result.weeks.joined().filter(\.hasActivity).count == 1)
    }

    @Test func doneSessionsKeepTheirIDsFromOldestToNewest() {
        let evening = Fixture.session("2026-11-10T18:00")
        let morning = Fixture.session("2026-11-10T07:00", kind: .run)
        let abandoned = Fixture.session("2026-11-10T20:00", status: .abandoned)
        let result = grid(sessions: [evening, abandoned, morning])
        #expect(day(result, "2026-11-10")?.sessions == [MonthDaySession(id: morning.id, kind: .run),
                                                       MonthDaySession(id: evening.id, kind: .strength)])
        #expect(day(result, "2026-11-11")?.sessions == [])
    }

    @Test func plannedShowsFromTodayOnlyAndFollowsOverrides() {
        let result = grid(sessions: [Fixture.session("2026-11-18T08:00")],
                          overrides: [Fixture.moved(nil, on: "2026-11-20", from: nil)])
        #expect(day(result, "2026-11-17")?.planned == nil, "Pas de prévu dans le passé")
        #expect(day(result, "2026-11-18")?.planned == nil, "Aujourd'hui est déjà fait")
        #expect(day(result, "2026-11-19")?.planned == .run)
        #expect(day(result, "2026-11-20")?.planned == nil)
        #expect(day(result, "2026-11-23")?.planned == .strength)
    }
}
