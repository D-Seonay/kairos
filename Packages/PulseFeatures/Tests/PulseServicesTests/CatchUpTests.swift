import Foundation
import PulseDomain
import PulseServices
import Testing

/// La semaine des fixtures : lun. Push, mar. Pull, mer. Legs (aujourd'hui), jeu. Endurance, ven. Push, sam. repos, dim. repos
/// imposé.
struct CatchUpTests {
    private typealias Fixture = PlanningFixtures
    private let calendar = TestClock.calendar
    private let monday = TestClock.date("2026-11-16T00:00")
    private let wednesdayNoon = TestClock.date("2026-11-18T12:00")
    private let now = TestClock.date("2026-11-18T12:00")

    private func week(overrides: [ScheduledDay] = [], sessions: [WorkoutSession] = []) -> [PlanningDay] {
        let context = ScheduleContext(program: Fixture.program(), overrides: overrides, sessions: sessions, restWeekdays: [.sunday],
                                      calendar: calendar)
        return WeekSchedule.days(weekStart: monday, context: context, now: wednesdayNoon)
    }

    @Test func onlyAMissedPastDayCanBeCaughtUp() {
        let days = week(sessions: [Fixture.session("2026-11-16T18:00")])
        #expect(days.map(CatchUp.canCatchUp) == [false, true, false, false, false, false, false])
    }

    @Test func targetsAreTheComingDaysRestDaysFirst() {
        let days = week()
        let targets = CatchUp.targets(for: days[1], in: days)
        #expect(targets.map(\.day.weekday) == [.saturday, .wednesday, .thursday, .friday], "Le repos imposé du dimanche n'est pas proposé")
        #expect(targets.map(\.replaces?.name) == [nil, "Legs", "Endurance", "Push"])
        #expect(targets.map(\.isRecommended) == [true, false, false, false])
    }

    @Test func aDoneDayIsNotATarget() {
        let days = week(sessions: [Fixture.session("2026-11-18T08:00")])
        #expect(!CatchUp.targets(for: days[1], in: days).contains { $0.day.weekday == .wednesday })
    }

    @Test func withoutRestDayNoTargetIsRecommended() {
        var program = Fixture.program()
        program.weekLayout = [Fixture.push.id, Fixture.pull.id, Fixture.legs.id, Fixture.run.id, Fixture.push.id, Fixture.pull.id, nil]
        let context = ScheduleContext(program: program, restWeekdays: [.sunday], calendar: calendar)
        let days = WeekSchedule.days(weekStart: monday, context: context, now: wednesdayNoon)
        let targets = CatchUp.targets(for: days[1], in: days)
        #expect(targets.count == 4 && targets.allSatisfy { !$0.isRecommended && $0.replaces != nil })
    }

    @Test func aDayThatIsNotMissedHasNoTarget() {
        let days = week()
        #expect(CatchUp.targets(for: days[3], in: days).isEmpty)
    }

    @Test func linesMoveTheMissedSessionAndMarkTheSourceCaughtUp() {
        let days = week()
        let lines = CatchUp.lines(source: days[1], target: days[5], programID: Fixture.programID, now: now)
        #expect(lines.target.routineDayID == Fixture.pull.id && lines.target.kind == .strength && lines.target.status == .planned)
        #expect(lines.target.movedFromDate == days[1].date && lines.target.moveReason == .user)
        #expect(lines.source.routineDayID == Fixture.pull.id && lines.source.status == .skipped && lines.source.moveReason == .user)
        #expect(CatchUp.isCaughtUp(lines.source) && !CatchUp.isCaughtUp(lines.target))
    }

    @Test func theWeekShowsTheSourceCaughtUpAndTheTargetPlanned() {
        let lines = CatchUp.lines(source: week()[1], target: week()[5], programID: Fixture.programID, now: now)
        let days = week(overrides: [lines.source, lines.target])
        #expect(days[1].state == .caughtUp && days[1].routine?.name == "Pull")
        #expect(days[5].state == .planned && days[5].routine?.name == "Pull" && days[5].movedFrom == days[1].date)
        #expect(!CatchUp.canCatchUp(days[1]), "Une séance ne se rattrape qu'une fois")
    }

    @Test func aSessionDoneOnTheSourceDayStillValidatesIt() {
        let lines = CatchUp.lines(source: week()[1], target: week()[5], programID: Fixture.programID, now: now)
        let days = week(overrides: [lines.source, lines.target], sessions: [Fixture.session("2026-11-17T20:00")])
        #expect(days[1].state == .done)
    }

    @Test func theRotationContinuesAfterTheCaughtUpSession() {
        let program = Fixture.program()
        let lines = CatchUp.lines(source: week()[1], target: week()[5], programID: Fixture.programID, now: now)
        let overrides = [lines.source, lines.target]
        let saturday = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-21T09:00"), calendar: calendar,
                                         overrides: overrides)
        #expect(saturday == .strength(Fixture.pull))
        let sunday = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-22T09:00"), calendar: calendar,
                                       overrides: overrides)
        #expect(sunday == .rest(next: NextSession(day: Fixture.push, weekday: .monday)))
        let today = TodayPlanner.plan(program: program, on: wednesdayNoon, calendar: calendar, overrides: overrides)
        #expect(today == .strength(Fixture.legs), "Les autres jours de la semaine ne bougent pas")
    }

    @Test func catchingUpOnALoadedDayReplacesItsSession() {
        let lines = CatchUp.lines(source: week()[1], target: week()[3], programID: Fixture.programID, now: now)
        let days = week(overrides: [lines.source, lines.target])
        #expect(days[3].routine?.name == "Pull" && days[3].state == .planned)
    }
}
