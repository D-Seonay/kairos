import Foundation
import PulseDomain
import PulseServices
import Testing

struct ProgramEditorTests {
    private struct Week {
        var program: Program
        var push: UUID
        var pull: UUID
        var legs: UUID
    }

    private func matheoProgram() -> Week {
        var program = ProgramEditor.emptyProgram(name: "PPL", now: .t0)
        let push, pull, legs: UUID
        (program, push) = ProgramEditor.addDay(named: "Push", exercises: [], to: program, now: .t0)
        (program, pull) = ProgramEditor.addDay(named: "Pull", exercises: [], to: program, now: .t0)
        (program, legs) = ProgramEditor.addDay(named: "Legs", exercises: [], to: program, now: .t0)
        for (weekday, day) in [(Weekday.monday, push), (.tuesday, pull), (.wednesday, legs), (.thursday, push), (.friday, pull)] {
            program = ProgramEditor.assign(day, to: weekday, in: program, now: .t1)
        }
        return Week(program: program, push: push, pull: pull, legs: legs)
    }

    @Test func emptyProgramHasNoDayAndAnEmptyWeek() {
        let program = ProgramEditor.emptyProgram(name: "Vide", now: .t0)
        #expect(program.name == "Vide" && program.days.isEmpty && program.templateID == nil && !program.isArchived)
        #expect(program.weekLayout == [UUID?](repeating: nil, count: 7))
        #expect(program.sessionsPerWeek == 0)
        #expect(program.createdAt == .t0 && program.updatedAt == .t0)
    }

    @Test func matheoWeekCountsFiveSessions() {
        let week = matheoProgram()
        let (program, push, pull, legs) = (week.program, week.push, week.pull, week.legs)
        #expect(program.weekLayout == [push, pull, legs, push, pull, nil, nil])
        #expect(program.sessionsPerWeek == 5)
        #expect(program.updatedAt == .t1)
        #expect(program.createdAt == .t0)
    }

    @Test func assigningNilClearsTheWeekdayAndRecountsSessions() {
        let week = matheoProgram()
        let (program, push, pull, legs) = (week.program, week.push, week.pull, week.legs)
        let cleared = ProgramEditor.assign(nil, to: .thursday, in: program, now: .t2)
        #expect(cleared.weekLayout == [push, pull, legs, nil, pull, nil, nil])
        #expect(cleared.sessionsPerWeek == 4)
        #expect(cleared.updatedAt == .t2)
    }

    @Test func assigningAnUnknownDayLeavesTheProgramUntouched() {
        let program = matheoProgram().program
        #expect(ProgramEditor.assign(UUID(), to: .saturday, in: program, now: .t2) == program)
    }

    @Test func addedDaysAreNumberedInOrderAndTheirExercisesNormalized() {
        let squat = RoutineExercise(order: 7, exercise: .content(id: "squat"), sets: 3, repsMin: 5, repsMax: 8, targetRPE: 8,
                                    restSeconds: 120, supersetGroup: 4)
        let (program, dayID) = ProgramEditor.addDay(named: "Legs", exercises: [squat], to: matheoProgram().program, now: .t2)
        #expect(program.days.map(\.order) == [0, 1, 2, 3])
        #expect(program.days[3].id == dayID && program.days[3].name == "Legs" && program.days[3].kind == .strength)
        #expect(program.days[3].exercises.map(\.order) == [0])
        #expect(program.days[3].exercises[0].supersetGroup == nil)
        #expect(program.updatedAt == .t2)
    }

    @Test func replacingADayKeepsItsPlaceInTheProgramAndTheWeek() {
        let week = matheoProgram()
        let (program, push, pull) = (week.program, week.push, week.pull)
        var edited = program.days[0]
        edited.name = "Push lourd"
        edited.order = 9
        let replaced = ProgramEditor.replaceDay(edited, in: program, now: .t2)
        #expect(replaced.days.map(\.name) == ["Push lourd", "Pull", "Legs"])
        #expect(replaced.days.map(\.order) == [0, 1, 2])
        #expect(replaced.weekLayout[0] == push && replaced.weekLayout[1] == pull)
        #expect(replaced.updatedAt == .t2)
        #expect(ProgramEditor.replaceDay(RoutineDay(order: 0, name: "?", kind: .strength), in: program, now: .t2) == program)
    }

    @Test func removingADayClearsItFromTheWeek() {
        let week = matheoProgram()
        let (program, push, pull, legs) = (week.program, week.push, week.pull, week.legs)
        let result = ProgramEditor.removeDay(id: push, from: program, now: .t2)
        let pullDay = result.days[0]
        #expect(result.weekLayout == [nil, pull, legs, nil, pull, nil, nil])
        #expect(result.days.map(\.order) == [0, 1])
        #expect(result.sessionsPerWeek == 3)
        #expect(result.updatedAt == .t2)
        let monday = TestClock.date("2026-11-02T08:00")
        #expect(TodayPlanner.plan(program: result, on: monday, calendar: TestClock.calendar)
                == .rest(next: NextSession(day: pullDay, weekday: .tuesday)))
    }

    @Test func duplicatingADayCopiesItWithNewIdentifiers() throws {
        let exercise = RoutineExercise(order: 0, exercise: .content(id: "squat"), sets: 3, repsMin: 5, repsMax: 8, targetRPE: 8,
                                       restSeconds: 120)
        var program = matheoProgram().program
        (program, _) = ProgramEditor.addDay(named: "Legs 2", exercises: [exercise], to: program, now: .t0)
        let source = try #require(program.days.last)
        let result = ProgramEditor.duplicateDay(id: source.id, in: program, now: .t2)
        let copy = try #require(result.days.last)
        #expect(result.days.count == program.days.count + 1)
        #expect(copy.name == "Legs 2 (copie)" && copy.order == result.days.count - 1)
        #expect(copy.id != source.id && copy.exercises[0].id != source.exercises[0].id)
        #expect(copy.exercises[0].exercise == source.exercises[0].exercise && copy.exercises[0].sets == 3)
        #expect(result.weekLayout == program.weekLayout && result.sessionsPerWeek == 5)
        #expect(result.updatedAt == .t2)
        #expect(ProgramEditor.duplicateDay(id: UUID(), in: program, now: .t2) == program)
    }

    @Test func renamingTrimsTheNameAndKeepsTheOldOneWhenBlank() {
        let program = matheoProgram().program
        let renamed = ProgramEditor.rename(program, to: "  Mon PPL  ", now: .t2)
        #expect(renamed.name == "Mon PPL" && renamed.updatedAt == .t2)
        #expect(ProgramEditor.rename(program, to: "   ", now: .t2).name == "PPL")
    }

    @Test func aBrokenWeekLayoutIsRepairedToSevenEntries() {
        var program = ProgramEditor.emptyProgram(name: "x", now: .t0)
        let day: UUID
        (program, day) = ProgramEditor.addDay(named: "A", exercises: [], to: program, now: .t0)
        program.weekLayout = [day]
        let result = ProgramEditor.assign(day, to: .sunday, in: program, now: .t1)
        #expect(result.weekLayout == [day, nil, nil, nil, nil, nil, day])
        #expect(result.sessionsPerWeek == 2)
    }
}
