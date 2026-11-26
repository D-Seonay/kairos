import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RunDayEditorTests {
    // MARK: Jour de course

    @Test func aNewRunDayIsAnEasyThirtyMinuteRun() {
        let day = RunDayEditor.make(order: 2)
        #expect(day.kind == .run && day.runType == .easy)
        #expect(day.runTargetMinutes == 30 && day.runTargetKm == nil)
        #expect(day.name == "Sortie facile" && day.order == 2 && day.exercises.isEmpty)
    }

    @Test func eachTypeHasItsDefaultGoal() {
        #expect(RunDayRules.defaultGoal(for: .easy) == .minutes(30))
        #expect(RunDayRules.defaultGoal(for: .intervals) == .minutes(30))
        #expect(RunDayRules.defaultGoal(for: .long) == .minutes(60))
        let long = RunDayEditor.make(type: .long, order: 0)
        #expect(long.name == "Sortie longue" && long.runTargetMinutes == 60)
    }

    @Test func theGoalIsADurationOrADistanceNeverBoth() {
        let day = RunDayEditor.make(order: 0)
        let distance = RunDayEditor.setGoal(.kilometres(10), in: day)
        #expect(distance.runTargetKm == 10 && distance.runTargetMinutes == nil)
        #expect(RunDayEditor.goal(of: distance) == .kilometres(10))
        let duration = RunDayEditor.setGoal(.minutes(45), in: distance)
        #expect(duration.runTargetMinutes == 45 && duration.runTargetKm == nil)
        let free = RunDayEditor.setGoal(.none, in: duration)
        #expect(free.runTargetMinutes == nil && free.runTargetKm == nil)
        #expect(RunDayEditor.goal(of: free) == .none)
    }

    @Test func aGoalOutOfBoundsIsBroughtBackInside() {
        let day = RunDayEditor.make(order: 0)
        #expect(RunDayEditor.setGoal(.minutes(2), in: day).runTargetMinutes == 10)
        #expect(RunDayEditor.setGoal(.minutes(900), in: day).runTargetMinutes == 240)
        #expect(RunDayEditor.setGoal(.kilometres(0), in: day).runTargetKm == 1)
        #expect(RunDayEditor.setGoal(.kilometres(250), in: day).runTargetKm == 60)
    }

    @Test func changingTheTypeRenamesTheDayAndKeepsItsGoal() {
        let day = RunDayEditor.setGoal(.kilometres(12), in: RunDayEditor.make(order: 0))
        let long = RunDayEditor.setType(.long, in: day)
        #expect(long.runType == .long && long.name == "Sortie longue")
        #expect(long.runTargetKm == 12 && long.id == day.id)
        // Le type déjà en place ne renomme rien : le nom d'un modèle (« Course facile ») reste.
        let template = RoutineDay(order: 0, name: "Course facile", kind: .run, runType: .easy, runTargetMinutes: 40)
        #expect(RunDayEditor.setType(.easy, in: template) == template)
    }

    @Test func aStoredDayWithBothTargetsKeepsTheDuration() {
        let both = RoutineDay(order: 0, name: "Footing", kind: .run, runType: nil, runTargetMinutes: 40, runTargetKm: 8)
        #expect(RunDayEditor.goal(of: both) == .minutes(40))
    }

    // MARK: Dans le programme

    private func program() -> (program: Program, push: UUID) {
        let empty = ProgramEditor.emptyProgram(name: "Hybride", now: .t0)
        let added = ProgramEditor.addDay(named: "Push", exercises: [], to: empty, now: .t0)
        return (added.program, added.dayID)
    }

    @Test func addingARunDayAppendsAUsableDay() throws {
        let (base, push) = program()
        let (result, runID) = ProgramEditor.addRunDay(to: base, now: .t1)
        #expect(result.days.map(\.id) == [push, runID])
        let run = try #require(result.days.last)
        #expect(run.kind == .run && run.runType == .easy && run.runTargetMinutes == 30 && run.order == 1)
        #expect(result.weekLayout == [UUID?](repeating: nil, count: 7), "Un jour ajouté n'entre pas seul dans la semaine")
        #expect(result.sessionsPerWeek == 0 && result.updatedAt == .t1)
    }

    @Test func aRunDayIsAssignedCountedAndRemovedLikeARoutine() {
        let (base, push) = program()
        var (result, runID) = ProgramEditor.addRunDay(type: .long, goal: .kilometres(15), to: base, now: .t1)
        result = ProgramEditor.assign(push, to: .monday, in: result, now: .t1)
        result = ProgramEditor.assign(runID, to: .sunday, in: result, now: .t1)
        #expect(result.weekLayout == [push, nil, nil, nil, nil, nil, runID])
        #expect(result.sessionsPerWeek == 2)
        let removed = ProgramEditor.removeDay(id: runID, from: result, now: .t2)
        #expect(removed.days.map(\.id) == [push])
        #expect(removed.weekLayout == [push, nil, nil, nil, nil, nil, nil] && removed.sessionsPerWeek == 1)
    }

    @Test func replacingARunDayKeepsOneGoalAndNoExercise() throws {
        let (base, _) = program()
        let (added, runID) = ProgramEditor.addRunDay(to: base, now: .t1)
        var edited = try #require(added.days.first { $0.id == runID })
        edited.runType = .intervals
        edited.runTargetMinutes = 500
        edited.runTargetKm = 8
        edited.exercises = [RoutineExercise(order: 0, exercise: .content(id: "squat"), sets: 3, repsMin: 5, repsMax: 8,
                                            targetRPE: 8, restSeconds: 120)]
        let replaced = ProgramEditor.replaceDay(edited, in: added, now: .t2)
        let run = try #require(replaced.days.first { $0.id == runID })
        #expect(run.kind == .run && run.runType == .intervals)
        #expect(run.runTargetMinutes == 240 && run.runTargetKm == nil && run.exercises.isEmpty)
    }

    /// Une course créée dans l'éditeur se lit comme celle d'un modèle : prévue le jour où elle est placée, titrée par son type,
    /// lancée avec son objectif, et jamais « jambes lourdes ».
    @Test func aCreatedRunDayIsPlannedAndLaunchedLikeATemplateRun() throws {
        let (base, push) = program()
        var (result, runID) = ProgramEditor.addRunDay(type: .intervals, goal: .kilometres(8), to: base, now: .t1)
        result = ProgramEditor.assign(push, to: .monday, in: result, now: .t1)
        result = ProgramEditor.assign(runID, to: .tuesday, in: result, now: .t1)
        // Le mardi 17 novembre 2026.
        let tuesday = TestClock.date("2026-11-17T09:00")
        guard case .run(let planned) = TodayPlanner.plan(program: result, on: tuesday, calendar: TestClock.calendar) else {
            Issue.record("expected a run on Tuesday")
            return
        }
        #expect(planned.id == runID)
        let launch = RunLaunch.planned(planned, programID: result.id, adjusted: nil)
        #expect(launch.title == "Fractionné" && launch.runType == .intervals && launch.routineDayID == runID)
        #expect(launch.targetKm == 8 && launch.targetMinutes == nil)
        #expect(!HeavyLegs.isHeavy(planned, directory: ExerciseDirectory(library: .bundled, userExercises: [])))
        let free = RunLaunch.planned(RunDayEditor.setGoal(.none, in: planned), programID: result.id, adjusted: nil)
        #expect(free.targetKm == nil && free.targetMinutes == nil && free.title == "Fractionné")
    }

    @Test func duplicatingARunDayCopiesItsTypeAndGoal() throws {
        let (base, _) = program()
        let (added, runID) = ProgramEditor.addRunDay(type: .long, goal: .minutes(75), to: base, now: .t1)
        let result = ProgramEditor.duplicateDay(id: runID, in: added, now: .t2)
        let copy = try #require(result.days.last)
        #expect(copy.id != runID && copy.kind == .run && copy.runType == .long && copy.runTargetMinutes == 75)
        #expect(copy.name == "Sortie longue (copie)")
    }
}
