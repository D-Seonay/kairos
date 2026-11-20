import Foundation
import PulseDomain
import PulseServices
import Testing

struct WeekScheduleTests {
    private typealias Fixture = PlanningFixtures
    private let calendar = TestClock.calendar
    private let monday = TestClock.date("2026-11-16T00:00")
    private let wednesdayNoon = TestClock.date("2026-11-18T12:00")

    private func week(overrides: [ScheduledDay] = [], sessions: [WorkoutSession] = [], rest: [Weekday] = [.sunday]) -> [PlanningDay] {
        let context = ScheduleContext(program: Fixture.program(), overrides: overrides, sessions: sessions, restWeekdays: rest,
                                      calendar: calendar)
        return WeekSchedule.days(weekStart: monday, context: context, now: wednesdayNoon)
    }

    @Test func weekStartsOnMonday() {
        #expect(WeekSchedule.weekStart(of: wednesdayNoon, calendar: calendar) == monday)
        #expect(WeekSchedule.weekStart(of: TestClock.date("2026-11-22T23:30"), calendar: calendar) == monday)
        #expect(WeekSchedule.weekStart(of: monday, calendar: calendar) == monday)
    }

    @Test func doneMissedPlannedAndRest() {
        let days = week(sessions: [Fixture.session("2026-11-16T18:00")])
        #expect(days.map(\.state) == [.done, .missed, .planned, .planned, .planned, .rest, .mandatoryRest])
        #expect(days.map(\.routine?.name) == ["Push", "Pull", "Legs", "Endurance", "Push", nil, nil])
        #expect(days[2].isToday && !days[2].isPast && days[1].isPast)
        #expect(days[0].sessions.count == 1)
    }

    @Test func anyStrengthSessionValidatesAStrengthDayButNotARunDay() {
        let days = week(sessions: [Fixture.session("2026-11-17T18:00"), Fixture.session("2026-11-18T07:00", kind: .run)])
        #expect(days[1].state == .done)
        #expect(days[2].state == .planned, "Une course ne valide pas un jour de jambes")
        #expect(days[2].sessions.count == 1)
    }

    @Test func abandonedAndInProgressSessionsAreIgnored() {
        let days = week(sessions: [Fixture.session("2026-11-16T18:00", status: .abandoned),
                                   Fixture.session("2026-11-18T09:00", status: .inProgress)])
        #expect(days[0].state == .missed && days[0].sessions.isEmpty)
        #expect(days[2].state == .planned)
    }

    @Test func sessionOnARestDayIsAnExtra() {
        let days = week(sessions: [Fixture.session("2026-11-15T10:00"), Fixture.session("2026-11-22T10:00", kind: .ride)])
        #expect(days[6].state == .done, "Un vélo le dimanche est montré comme fait")
        #expect(days[0].state == .missed, "La séance de la veille de la semaine ne compte pas")
    }

    @Test func overridesReplaceTheTemplate() {
        let overrides = [Fixture.moved(Fixture.legs, on: "2026-11-19", from: "2026-11-18"),
                         Fixture.moved(Fixture.run, on: "2026-11-18", from: "2026-11-19")]
        let days = week(overrides: overrides)
        #expect(days[2].routine?.name == "Endurance" && days[3].routine?.name == "Legs")
        #expect(days[3].movedFrom == TestClock.date("2026-11-18T00:00"))
    }

    @Test func restOverrideEmptiesTheDay() {
        let days = week(overrides: [Fixture.moved(nil, on: "2026-11-20", from: nil)])
        #expect(days[4].routine == nil && days[4].state == .rest)
    }

    @Test func overrideOfAnotherProgramIsIgnored() {
        var line = Fixture.moved(nil, on: "2026-11-20", from: nil)
        line.programID = UUID()
        #expect(week(overrides: [line])[4].routine?.name == "Push")
    }

    @Test func onlyFutureUnvalidatedDaysMove() {
        let days = week(sessions: [Fixture.session("2026-11-18T08:00")])
        #expect(days.map(\.isMovable) == [false, false, false, true, true, true, true])
    }

    @Test func todayPlannerFollowsOverridesForTodayAndTheNextSession() {
        let program = Fixture.program()
        let overrides = [Fixture.moved(nil, on: "2026-11-18", from: nil),
                         Fixture.moved(Fixture.legs, on: "2026-11-21", from: "2026-11-18")]
        let today = TodayPlanner.plan(program: program, on: wednesdayNoon, calendar: calendar, overrides: overrides)
        #expect(today == .rest(next: NextSession(day: Fixture.run, weekday: .thursday)))
        let saturday = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-21T09:00"), calendar: calendar,
                                         overrides: overrides)
        #expect(saturday == .strength(Fixture.legs))
    }
}
