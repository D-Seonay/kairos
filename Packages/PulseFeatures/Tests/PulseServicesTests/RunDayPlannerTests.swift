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

    @Test func theWeekSplitSharesTheSessionsBetweenStrengthAndRuns() {
        let split = WeekSplit(focus: 0.5, daysPerWeek: 3)
        #expect(split.sessions == 3 && split.runs == 1 && split.strength == 2)
        #expect(WeekSplit(focus: 0.2, daysPerWeek: 6) == WeekSplit(sessions: 6, runs: 1))
        #expect(WeekSplit(sessions: 3, runs: 9) == WeekSplit(sessions: 3, runs: 3), "Pas plus de sorties que de séances")
        #expect(WeekSplit(sessions: 3, runs: 9).strength == 0)
    }

    // MARK: Jours libres

    @Test func aSingleRunIsEasyOnTheFirstFreeDay() {
        let week = [push, nil, pull, nil, push, nil, nil]
        #expect(place(1, in: week) == [Placement(weekdayIndex: 1, type: .easy)])
        #expect(place(0, in: week).isEmpty)
    }

    @Test func twoRunsAreOneLongAtTheEndOfTheWeekAndOneEasyAwayFromIt() {
        let placements = place(2, in: [push, nil, pull, nil, push, nil, nil])
        #expect(placements == [Placement(weekdayIndex: 6, type: .long),
                               Placement(weekdayIndex: 3, type: .easy)])
    }

    @Test func threeRunsKeepASingleLongRun() {
        let placements = place(3, in: [push, nil, pull, nil, push, nil, nil])
        #expect(placements.map(\.type) == [.long, .easy, .easy])
        #expect(placements.map(\.weekdayIndex) == [6, 3, 1])
    }

    @Test func aWeekThatAlreadyHasALongRunOnlyGetsEasyRuns() {
        let placements = place(2, in: [push, nil, pull, nil, push, nil, longRun])
        #expect(placements.map(\.type) == [.easy, .easy])
        #expect(placements.map(\.weekdayIndex) == [3, 1])
    }

    @Test func aShortWeekIsReadAsSevenDays() {
        // Le plus loin de la séance du lundi : le jeudi (le vendredi est aussi loin, le plus tôt l'emporte).
        #expect(place(1, in: [push]) == [Placement(weekdayIndex: 3, type: .easy)])
    }

    // MARK: Jambes lourdes

    @Test func aRunAvoidsTheDayAfterHeavyLegsWhenAnotherDayIsFree() {
        // Pas le mardi, lendemain des jambes ; parmi les autres, le vendredi est le plus loin des deux séances.
        #expect(place(1, in: [legs, nil, push, nil, nil, nil, nil]).map(\.weekdayIndex) == [4])
        // La semaine se répète : le lundi suit les jambes du dimanche.
        #expect(place(1, in: [nil, push, nil, pull, nil, nil, legs]).map(\.weekdayIndex) == [2])
    }

    @Test func theOnlyFreeDayIsUsedEvenAfterHeavyLegs() {
        let placements = place(1, in: [push, pull, legs, nil, push, pull, push])
        #expect(placements == [Placement(weekdayIndex: 3, type: .easy)])
    }

    @Test func betweenTwoHeavyLegDaysTheHeaviestIsAvoidedFirst() {
        let week = [legs, nil, lightLegs, nil, push, pull, push]
        #expect(place(1, in: week).map(\.weekdayIndex) == [3], "Jeudi suit les jambes légères, mardi les plus lourdes")
        let both = place(2, in: week)
        #expect(both.map(\.weekdayIndex) == [3, 1])
        #expect(both.map(\.type) == [.easy, .easy], "Pas de sortie longue le lendemain d'une séance de jambes lourde")
    }

    // MARK: Semaine pleine

    @Test func withoutAFreeDayNoRunIsPlaced() {
        let rest: [Weekday] = [.tuesday, .thursday, .saturday, .sunday]
        #expect(place(1, in: [push, nil, pull, nil, push, nil, nil], rest: rest).isEmpty, "Une séance de musculation ne cède pas sa place")
        #expect(place(2, in: [push, pull, legs, push, pull, push, pull]).isEmpty)
        #expect(place(2, in: [nil, nil, nil, nil, nil, nil, nil], rest: Weekday.allCases).isEmpty)
    }

    @Test func runsBeyondTheFreeDaysAreLeftOut() {
        let placements = place(3, in: [push, nil, pull, nil, push, nil, nil], rest: [.thursday, .saturday, .sunday])
        #expect(placements == [Placement(weekdayIndex: 1, type: .easy)], "Un seul jour libre : une seule sortie, donc facile")
        let two = place(5, in: [push, nil, pull, nil, push, nil, nil], rest: [.saturday, .sunday])
        #expect(two.map(\.weekdayIndex) == [3, 1] && two.map(\.type) == [.long, .easy])
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
        let result = RunDayPlanner.adding(runs: 3, upTo: 6, to: base, restWeekdays: [], directory: Fixture.directory)
        #expect(kinds(result) == [.strength, .run, .strength, .run, .strength, nil, .run])
        #expect(result.sessionsPerWeek == 6)
        let runs = result.days.filter { $0.kind == .run }
        #expect(runs.map(\.name) == ["Sortie longue", "Sortie facile"], "Une seule sortie facile, placée deux fois")
        #expect(runs.map(\.runTargetMinutes) == [60, 30])
        #expect(result.days.map(\.order) == Array(0..<result.days.count))
        let easy = try #require(runs.last)
        #expect(result.weekLayout[1] == easy.id && result.weekLayout[3] == easy.id && result.weekLayout[6] == runs.first?.id)
        #expect(RunDayPlanner.adding(runs: 0, upTo: 6, to: base, restWeekdays: [], directory: Fixture.directory) == base)
    }

    @Test func theWeekNeverGoesBeyondTheSessionsAsked() {
        let base = program([push, nil, pull, nil, push, nil, nil])
        let five = RunDayPlanner.adding(runs: 3, upTo: 5, to: base, restWeekdays: [], directory: Fixture.directory)
        #expect(kinds(five) == [.strength, nil, .strength, .run, .strength, nil, .run], "3 sorties demandées, 2 places sous 5 séances")
        #expect(five.sessionsPerWeek == 5)
        #expect(RunDayPlanner.adding(runs: 3, upTo: 3, to: base, restWeekdays: [], directory: Fixture.directory) == base)
        #expect(RunDayPlanner.adding(runs: 3, upTo: 2, to: base, restWeekdays: [], directory: Fixture.directory) == base,
                "Un programme déjà au-dessus de la demande reste tel quel")
    }

    @Test func aFullWeekKeepsEveryStrengthDay() {
        let base = program([push, pull, legs, push, legs, push, legs])
        #expect(RunDayPlanner.adding(runs: 2, upTo: 9, to: base, restWeekdays: [], directory: Fixture.directory) == base)
    }

    // MARK: À l'adoption

    private let library = ContentLibrary.bundled
    private var adopter: ProgramAdopter { ProgramAdopter(library: library) }

    private func adopt(_ id: String, split: WeekSplit?, rest: [Weekday] = []) throws -> Program {
        let template = try #require(library.programTemplate(id: id))
        return adopter.adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: rest, split: split, now: .t0)
    }

    private func names(_ program: Program) -> [String?] {
        program.weekLayout.map { id in id.flatMap { id in program.days.first { $0.id == id }?.name } }
    }

    @Test func theRunsOfTheTemplateCountAndAreNeverRemoved() throws {
        let plain = try adopt("runner-strength", split: nil)
        for split in [WeekSplit(sessions: 3, runs: 0), WeekSplit(sessions: 3, runs: 2), WeekSplit(sessions: 5, runs: 3),
                      WeekSplit(sessions: 6, runs: 3), WeekSplit(sessions: 5, runs: 5)] {
            let adopted = try adopt("runner-strength", split: split)
            #expect(names(adopted) == names(plain), "\(split) : le modèle reste entier, rien n'est ajouté")
            #expect(adopted.days.count == plain.days.count)
        }
        let six = try adopt("runner-strength", split: WeekSplit(sessions: 6, runs: 5))
        #expect(kinds(six).filter { $0 == .run }.count == 4 && kinds(six).filter { $0 == .strength }.count == 2,
                "5 sorties demandées, une seule place sous 6 séances")
        #expect(six.sessionsPerWeek == 6)
        #expect(six.days.count == plain.days.count, "La sortie ajoutée reprend la course facile du modèle")
    }

    @Test func aBalancedTemplateKeepsItsFirstRoutinesAndGetsTheRuns() throws {
        let adopted = try adopt("full-body", split: WeekSplit(sessions: 3, runs: 1), rest: [.tuesday])
        // Les deux routines gardées s'étalent sur les jours du modèle (lundi, vendredi), la sortie se pose entre elles.
        #expect(names(adopted) == ["Full Body A", nil, "Sortie facile", nil, "Full Body B", nil, nil])
        #expect(adopted.sessionsPerWeek == 3 && adopted.templateID == "full-body")
        #expect(adopted.days.map(\.name) == ["Full Body A", "Full Body B", "Full Body C", "Sortie facile"],
                "Full Body C reste dans le programme, hors semaine")
        let run = try #require(adopted.days.last)
        #expect(run.kind == .run && run.runType == .easy && run.runTargetMinutes == 30)

        let upperLower = try adopt("upper-lower", split: WeekSplit(sessions: 4, runs: 1))
        #expect(names(upperLower) == ["Haut A", "Sortie facile", nil, "Bas A", "Haut B", nil, nil])
        #expect(upperLower.days.contains { $0.name == "Bas B" } && !names(upperLower).contains("Bas B"))
    }

    @Test func aBalancedTemplateAlwaysKeepsOneStrengthDay() throws {
        let adopted = try adopt("full-body", split: WeekSplit(sessions: 3, runs: 3))
        #expect(kinds(adopted).filter { $0 == .strength }.count == 1 && names(adopted).first == "Full Body A")
        #expect(kinds(adopted).filter { $0 == .run }.count == 2 && adopted.sessionsPerWeek == 3)
    }

    @Test func aSplitIsAdoptedWholeAndOnlyGetsTheRunsThatFit() throws {
        let plain = try adopt("ppl-3", split: nil)
        let three = try adopt("ppl-3", split: WeekSplit(sessions: 3, runs: 1))
        #expect(names(three) == names(plain) && three.days.count == plain.days.count, "3 séances : pas de place pour la sortie")
        let two = try adopt("ppl-3", split: WeekSplit(sessions: 2, runs: 1))
        #expect(names(two) == names(plain), "Le modèle seul dépasse la demande : rien ne s'ajoute, rien ne se retire")
        let four = try adopt("ppl-3", split: WeekSplit(sessions: 4, runs: 1))
        #expect(names(four) == ["Push", "Sortie facile", "Pull", nil, "Legs", nil, nil])
        let six = try adopt("ppl-6", split: WeekSplit(sessions: 6, runs: 1))
        #expect(names(six) == names(try adopt("ppl-6", split: nil)))
    }

    @Test func adoptingWithoutASplitCopiesTheTemplate() throws {
        #expect(kinds(try adopt("full-body", split: nil)) == [.strength, nil, .strength, nil, .strength, nil, nil])
    }
}
