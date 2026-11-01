import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct TodayPlannerTests {
    private let calendar = TestClock.calendar

    private func program(_ templateID: String) throws -> Program {
        let template = try #require(ContentLibrary.bundled.programTemplate(id: templateID))
        return Program(template: template, now: TestClock.date("2026-11-02T08:00"))
    }

    @Test func weekdayIsMondayFirst() {
        #expect(Weekday(date: TestClock.date("2026-11-02T08:00"), calendar: calendar) == .monday)
        #expect(Weekday(date: TestClock.date("2026-11-08T23:30"), calendar: calendar) == .sunday)
        #expect(Weekday.monday.index == 0)
        #expect(Weekday.sunday.index == 6)
    }

    @Test func mondayOfPPL3IsPush() throws {
        let program = try program("ppl-3")
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-02T08:00"), calendar: calendar)
        #expect(plan == .strength(program.days[0]))
        #expect(program.days[0].name == "Push")
    }

    @Test func sundayIsRestWithNextPush() throws {
        let program = try program("ppl-3")
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-08T08:00"), calendar: calendar)
        #expect(plan == .rest(next: NextSession(day: program.days[0], weekday: .monday)))
    }

    @Test func tuesdayIsRestWithNextPull() throws {
        let program = try program("ppl-3")
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-03T08:00"), calendar: calendar)
        #expect(plan == .rest(next: NextSession(day: program.days[1], weekday: .wednesday)))
    }

    @Test func noProgram() {
        #expect(TodayPlanner.plan(program: nil, on: TestClock.date("2026-11-02T08:00"), calendar: calendar) == .noProgram)
    }

    @Test func runDay() throws {
        let program = try program("runner-strength")
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-02T08:00"), calendar: calendar)
        guard case .run(let day) = plan else {
            Issue.record("Un jour de course était attendu, obtenu \(plan)")
            return
        }
        #expect(day.runType == .easy)
    }

    @Test func emptyWeekHasNoNextSession() throws {
        var program = try program("ppl-3")
        program.weekLayout = Array(repeating: nil, count: 7)
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-02T08:00"), calendar: calendar)
        #expect(plan == .rest(next: nil))
    }

    @Test func singleSessionLoopsToNextWeek() throws {
        var program = try program("ppl-3")
        program.weekLayout = [nil, nil, nil, nil, nil, nil, nil]
        program.weekLayout[2] = program.days[1].id
        let plan = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-04T08:00"), calendar: calendar)
        #expect(plan == .strength(program.days[1]))
        let other = TodayPlanner.plan(program: program, on: TestClock.date("2026-11-05T08:00"), calendar: calendar)
        #expect(other == .rest(next: NextSession(day: program.days[1], weekday: .wednesday)))
    }
}
