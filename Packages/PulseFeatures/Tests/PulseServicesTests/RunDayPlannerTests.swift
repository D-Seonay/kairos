import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct RunDayPlannerTests {
    private typealias Fixture = RuleFixtures
    private typealias Placement = RunDayPlanner.Placement

    private let push = Fixture.push
    private let pull = Fixture.pull
    private let legs = Fixture.legs
    /// Une séance de jambes lourde, mais moins que `legs` : 5 séries de jambes contre 10.
    private let lightLegs = RoutineDay(order: 4, name: "Jambes légères", kind: .strength, exercises: [
        Fixture.exercise("back-squat-barbell", sets: 3), Fixture.exercise("leg-press-machine", sets: 2)
    ])
    private let longRun = RoutineDay(order: 5, name: "Sortie longue", kind: .run, runType: .long, runTargetMinutes: 60)

    private func place(_ count: Int, in week: [RoutineDay?], rest: [Weekday] = []) -> [Placement] {
        RunDayPlanner.placements(adding: count, to: week, restWeekdays: rest, directory: Fixture.directory)
    }

    // MARK: Ce que le curseur demande

    @Test func theSliderAsksForTheDaysThatStrengthLeaves() {
        #expect(RunDayPlanner.requestedRuns(focus: 0.5, daysPerWeek: 3) == 1)
        #expect(RunDayPlanner.requestedRuns(focus: 0.4, daysPerWeek: 5) == 2)
        #expect(RunDayPlanner.requestedRuns(focus: 0, daysPerWeek: 4) == 0)
        #expect(RunDayPlanner.requestedRuns(focus: 1, daysPerWeek: 6) == 6)
        #expect(RunDayPlanner.requestedRuns(focus: 3, daysPerWeek: 4) == 4, "Un curseur hors bornes ne demande pas plus que les jours")
    }

    // MARK: Jours libres

    @Test func aSingleRunIsEasyOnTheFirstFreeDay() {
        let week = [push, nil, pull, nil, push, nil, nil]
        #expect(place(1, in: week) == [Placement(weekdayIndex: 1, type: .easy, replacesStrength: false)])
        #expect(place(0, in: week).isEmpty)
    }

    @Test func twoRunsAreOneLongAtTheEndOfTheWeekAndOneEasyAwayFromIt() {
        let placements = place(2, in: [push, nil, pull, nil, push, nil, nil])
        #expect(placements == [Placement(weekdayIndex: 6, type: .long, replacesStrength: false),
                               Placement(weekdayIndex: 3, type: .easy, replacesStrength: false)])
    }

    @Test func threeRunsKeepASingleLongRun() {
        let placements = place(3, in: [push, nil, pull, nil, push, nil, nil])
        #expect(placements.map(\.type) == [.long, .easy, .easy])
        #expect(placements.map(\.weekdayIndex) == [6, 3, 1])
        #expect(placements.allSatisfy { !$0.replacesStrength })
    }

    @Test func aWeekThatAlreadyHasALongRunOnlyGetsEasyRuns() {
        let placements = place(2, in: [push, nil, pull, nil, push, nil, longRun])
        #expect(placements.map(\.type) == [.easy, .easy])
        #expect(placements.map(\.weekdayIndex) == [3, 1])
    }

    @Test func aShortWeekIsReadAsSevenDays() {
        #expect(place(1, in: [push]) == [Placement(weekdayIndex: 1, type: .easy, replacesStrength: false)])
    }

    // MARK: Jambes lourdes

    @Test func aRunAvoidsTheDayAfterHeavyLegsWhenAnotherDayIsFree() {
        #expect(place(1, in: [legs, nil, push, nil, nil, nil, nil]).map(\.weekdayIndex) == [3])
        // La semaine se répète : le lundi suit les jambes du dimanche.
        #expect(place(1, in: [nil, push, nil, pull, nil, nil, legs]).map(\.weekdayIndex) == [2])
    }

    @Test func theOnlyFreeDayIsUsedEvenAfterHeavyLegs() {
        let placements = place(1, in: [push, pull, legs, nil, push, pull, push])
        #expect(placements == [Placement(weekdayIndex: 3, type: .easy, replacesStrength: false)])
    }

    @Test func betweenTwoHeavyLegDaysTheHeaviestIsAvoidedFirst() {
        let week = [legs, nil, lightLegs, nil, push, pull, push]
        #expect(place(1, in: week).map(\.weekdayIndex) == [3], "Jeudi suit les jambes légères, mardi les plus lourdes")
        let both = place(2, in: week)
        #expect(both.map(\.weekdayIndex) == [3, 1])
        #expect(both.map(\.type) == [.easy, .easy], "Pas de sortie longue le lendemain d'une séance de jambes lourde")
    }

    // MARK: Semaine pleine

    @Test func withoutAFreeDayTheRunTakesTheLightestStrengthDay() {
        let rest: [Weekday] = [.tuesday, .thursday, .saturday, .sunday]
        let placements = place(1, in: [push, nil, pull, nil, push, nil, nil], rest: rest)
        #expect(placements == [Placement(weekdayIndex: 2, type: .easy, replacesStrength: true)], "Pull : 4 séries contre 7")
    }

    @Test func aFullWeekGivesUpItsLightestSessionsOneByOne() {
        let placements = place(2, in: [push, pull, legs, push, pull, push, pull])
        #expect(placements.map(\.weekdayIndex) == [1, 4])
        #expect(placements.allSatisfy { $0.replacesStrength && $0.type == .easy })
    }

    @Test func mandatoryRestDaysNeverGetARun() {
        let placements = place(3, in: [push, nil, pull, nil, push, nil, nil], rest: [.thursday, .saturday, .sunday])
        #expect(placements.map(\.weekdayIndex) == [1, 2, 0], "Mardi libre, puis les séances les plus légères")
        #expect(place(2, in: [nil, nil, nil, nil, nil, nil, nil], rest: Weekday.allCases).isEmpty, "Aucune place : rien n'est posé")
    }

    // MARK: Dans le programme

    private func program(_ week: [RoutineDay?]) -> Program {
        var days: [RoutineDay] = []
        for day in week.compactMap({ $0 }) where !days.contains(where: { $0.id == day.id }) { days.append(day) }
        return Program(name: "Semaine", sessionsPerWeek: week.compactMap { $0 }.count, weekLayout: week.map { $0?.id },
                       days: days, createdAt: .t0, updatedAt: .t0)
    }

    private func kinds(_ program: Program) -> [RoutineDayKind?] {
        program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.kind } }
    }

    @Test func theProgramGetsOneLongRunAndASharedEasyRun() throws {
        let base = program([push, nil, pull, nil, push, nil, nil])
        let result = RunDayPlanner.adding(runs: 3, to: base, restWeekdays: [], directory: Fixture.directory)
        #expect(kinds(result) == [.strength, .run, .strength, .run, .strength, nil, .run])
        #expect(result.sessionsPerWeek == 6)
        let runs = result.days.filter { $0.kind == .run }
        #expect(runs.map(\.name) == ["Sortie longue", "Sortie facile"], "Une seule sortie facile, placée deux fois")
        #expect(runs.map(\.runTargetMinutes) == [60, 30])
        #expect(result.days.map(\.order) == Array(0..<result.days.count))
        let easy = try #require(runs.last)
        #expect(result.weekLayout[1] == easy.id && result.weekLayout[3] == easy.id && result.weekLayout[6] == runs.first?.id)
        #expect(RunDayPlanner.adding(runs: 0, to: base, restWeekdays: [], directory: Fixture.directory) == base)
    }

    @Test func aReplacedStrengthDayStaysInTheProgramOutsideTheWeek() {
        let base = program([push, pull, legs, push, legs, push, legs])
        let result = RunDayPlanner.adding(runs: 1, to: base, restWeekdays: [], directory: Fixture.directory)
        #expect(kinds(result) == [.strength, .run, .strength, .strength, .strength, .strength, .strength])
        #expect(result.days.contains { $0.id == pull.id }, "Pull reste une routine du programme")
        #expect(!result.weekLayout.contains(pull.id))
        #expect(result.sessionsPerWeek == 7)
    }

    @Test func theRunsOfTheTemplateCountAndAreNeverRemoved() throws {
        let library = ContentLibrary.bundled
        let template = try #require(library.programTemplate(id: "runner-strength"))
        let adopter = ProgramAdopter(library: library)
        let plain = adopter.adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: .t0)
        for runs in [0, 2, 3] {
            let adopted = adopter.adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], runs: runs, now: .t0)
            #expect(kinds(adopted) == kinds(plain), "\(runs) sorties demandées : les trois du modèle restent")
            #expect(adopted.days.count == plain.days.count)
        }
        let five = adopter.adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], runs: 5, now: .t0)
        #expect(kinds(five) == [.run, .strength, .run, .run, .strength, .run, .run])
        #expect(five.days.count == plain.days.count, "Les sorties ajoutées reprennent la course facile du modèle")
        let easy = try #require(five.days.first { $0.runType == .easy })
        #expect(five.weekLayout.filter { $0 == easy.id }.count == 3)
        #expect(five.sessionsPerWeek == 7)
    }

    @Test func adoptingWithRunsKeepsTheStrengthDaysOfTheTemplate() throws {
        let library = ContentLibrary.bundled
        let template = try #require(library.programTemplate(id: "full-body"))
        let adopted = ProgramAdopter(library: library).adopt(template, equipment: .fullGym, painAreas: [],
                                                             restWeekdays: [.tuesday], runs: 1, now: .t0)
        #expect(kinds(adopted) == [.strength, nil, .strength, .run, .strength, nil, nil])
        #expect(adopted.sessionsPerWeek == 4 && adopted.templateID == "full-body")
        let run = try #require(adopted.days.last)
        #expect(run.kind == .run && run.runType == .easy && run.runTargetMinutes == 30)
    }
}
