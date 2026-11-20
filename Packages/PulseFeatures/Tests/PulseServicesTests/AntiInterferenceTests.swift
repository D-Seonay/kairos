import Foundation
import PulseDomain
import PulseServices
import Testing

struct AntiInterferenceTests {
    private typealias Fixture = RuleFixtures

    private func placesRest(_ input: AntiInterferenceInput) -> Bool {
        AntiInterference.plan(input).lines.contains { $0.reason == .antiInterferenceRestDay }
    }

    @Test func heavyLegsNeedsMoreThanHalfOfTheWorkingSetsOnLegMuscles() {
        #expect(HeavyLegs.isHeavy(Fixture.legs, directory: Fixture.directory), "10 séries de jambes sur 13")
        #expect(!HeavyLegs.isHeavy(Fixture.push, directory: Fixture.directory))
        let half = RoutineDay(order: 0, name: "Mixte", kind: .strength, exercises: [
            Fixture.exercise("back-squat-barbell", sets: 3), Fixture.exercise("bench-press-barbell", sets: 3)
        ])
        #expect(!HeavyLegs.isHeavy(half, directory: Fixture.directory), "La moitié ne suffit pas")
        let done = Fixture.session("2026-11-15T10:00",
                                   exercises: ["back-squat-barbell", "romanian-deadlift-barbell", "bench-press-barbell"])
        #expect(HeavyLegs.isHeavy(done, directory: Fixture.directory))
    }

    @Test func intervalsTheDayAfterHeavyLegsMoveToTheFirstFreeDay() {
        let plan = AntiInterference.plan(Fixture.input())
        #expect(plan.lines.count == 2)
        #expect(plan.lines[0].date == Fixture.day("2026-11-19") && plan.lines[0].routine == nil)
        #expect(plan.lines[1].date == Fixture.day("2026-11-21") && plan.lines[1].routine?.id == Fixture.intervals.id)
        #expect(plan.lines[1].movedFromDate == Fixture.day("2026-11-19"))
        #expect(plan.lines.allSatisfy { $0.reason == .antiInterferenceAfterHeavyLegs })
        #expect(plan.managedDates.count == 7)
    }

    @Test func anEasyRunStaysWhereItIs() {
        let easy = RoutineDay(order: 3, name: "Endurance", kind: .run, runType: .easy, runTargetMinutes: 45)
        #expect(AntiInterference.plan(Fixture.input(program: Fixture.program(thursday: easy))).lines.isEmpty)
    }

    @Test func withoutAFreeDayTheRunBecomesEasy() throws {
        let plan = AntiInterference.plan(Fixture.input(rest: [.saturday, .sunday]))
        let line = try #require(plan.lines.first)
        #expect(plan.lines.count == 1 && line.date == Fixture.day("2026-11-19"))
        #expect(line.routine?.id == Fixture.intervals.id && line.movedFromDate == nil)

        let program = Fixture.program()
        let today = TodayPlanner.routineDay(of: program, on: Fixture.day("2026-11-19"), calendar: TestClock.calendar,
                                            overrides: [Fixture.scheduled(line)])
        #expect(today?.runType == .easy && today?.id == Fixture.intervals.id)
    }

    @Test func aDisabledRuleWritesNothing() {
        #expect(AntiInterference.plan(Fixture.input(disabled: [.noIntenseRunAfterHeavyLegs])).lines.isEmpty)
    }

    @Test func userLinesAndDoneDaysAreLeftAlone() {
        var user = Fixture.scheduled(RuleLine(date: Fixture.day("2026-11-19"), routine: Fixture.intervals, reason: .user, text: ""))
        user.moveReasonText = nil
        let plan = AntiInterference.plan(Fixture.input(lines: [user]))
        #expect(plan.lines.isEmpty, "L'utilisateur a choisi le fractionné du jeudi")
        #expect(!plan.managedDates.contains(Fixture.day("2026-11-19")))

        let ran = AntiInterference.plan(Fixture.input(sessions: [Fixture.session("2026-11-19T07:00", kind: .run)],
                                                      now: "2026-11-19T12:00"))
        #expect(ran.lines.isEmpty && ran.managedDates.count == 3)
    }

    @Test func heavyLegsDoneOnSundayMovesMondayIntervals() {
        let monday = RoutineDay(order: 0, name: "Fractionné", kind: .run, runType: .intervals, runTargetMinutes: 40)
        let program = Program(id: Fixture.programID, name: "Hybride", sessionsPerWeek: 2,
                              weekLayout: [monday.id, nil, nil, nil, nil, nil, nil], days: [monday], createdAt: Fixture.created,
                              updatedAt: Fixture.created)
        let legs = Fixture.session("2026-11-15T10:00", exercises: ["back-squat-barbell", "leg-press-machine"])
        let plan = AntiInterference.plan(Fixture.input(program: program, sessions: [legs]))
        #expect(plan.lines.map(\.date) == [Fixture.day("2026-11-16"), Fixture.day("2026-11-17")])
    }

    @Test func recomputingFromItsOwnLinesGivesTheSamePlan() {
        let plan = AntiInterference.plan(Fixture.input())
        let again = AntiInterference.plan(Fixture.input(lines: plan.lines.map(Fixture.scheduled)))
        #expect(again == plan)
    }

    @Test func sevenBusyDaysAndShortSleepPlaceARestDay() throws {
        let sessions = (9...15).map { Fixture.session("2026-11-\($0)T18:00") }
        let short = (10...16).map { Fixture.night("2026-11-\($0)", asleepMinutes: 300) }
        let plan = AntiInterference.plan(Fixture.input(sessions: sessions, nights: short))
        let rest = try #require(plan.lines.first)
        #expect(rest.date == Fixture.day("2026-11-16") && rest.routine == nil && rest.reason == .antiInterferenceRestDay)

        let long = (10...16).map { Fixture.night("2026-11-\($0)", asleepMinutes: 480) }
        #expect(!placesRest(Fixture.input(sessions: sessions, nights: long)))
        let few = (14...16).map { Fixture.night("2026-11-\($0)", asleepMinutes: 300) }
        #expect(!placesRest(Fixture.input(sessions: sessions, nights: few)), "Il faut au moins 4 nuits")
        let rested = sessions.filter { !TestClock.calendar.isDate($0.startedAt, inSameDayAs: Fixture.day("2026-11-12")) }
        #expect(!placesRest(Fixture.input(sessions: rested, nights: short)))
    }

    @Test func aRestDayOnHeavyLegsDayCancelsTheRunMove() {
        let sessions = (12...18).map { Fixture.session("2026-11-\($0)T18:00") }
        let short = (13...19).map { Fixture.night("2026-11-\($0)", asleepMinutes: 300) }
        let plan = AntiInterference.plan(Fixture.input(sessions: sessions.filter { $0.startedAt < Fixture.day("2026-11-19") },
                                                       nights: short, now: "2026-11-19T07:00"))
        #expect(plan.lines.map(\.reason) == [.antiInterferenceRestDay], "Le fractionné du jeudi devient le repos")
        #expect(plan.lines.first?.date == Fixture.day("2026-11-19"))
    }

    @Test func sameDayReminderOnlyForTodayWithTheOtherDisciplineDone() {
        let context = ScheduleContext(program: Fixture.program(), sessions: [Fixture.session("2026-11-16T07:00", kind: .run)],
                                      calendar: TestClock.calendar)
        let today = WeekSchedule.day(on: Fixture.day("2026-11-16"), context: context, today: Fixture.day("2026-11-16"))
        #expect(AntiInterference.needsSpacing(today))
        let tomorrow = WeekSchedule.day(on: Fixture.day("2026-11-17"), context: context, today: Fixture.day("2026-11-16"))
        #expect(!AntiInterference.needsSpacing(tomorrow))
    }
}
