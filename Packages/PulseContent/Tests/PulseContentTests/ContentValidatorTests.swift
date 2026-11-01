import Foundation
import PulseContent
import PulseDomain
import Testing

private let countRules: Set<ContentRule> = [.exerciseCount, .patternPopulation]

private func rules(_ library: ContentLibrary, ignoring: Set<ContentRule> = countRules) -> [ContentRule] {
    ContentValidator.issues(in: library, ignoring: ignoring).map(\.rule)
}

@Test func validMinimalLibraryHasNoIssuesExceptCount() {
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat))
    #expect(ContentValidator.issues(in: lib, ignoring: countRules).isEmpty)
    #expect(rules(lib, ignoring: []).contains(.exerciseCount))
    #expect(!rules(lib, ignoring: []).contains(.patternPopulation))
}

@Test(arguments: ["Bench", "bench_press", "-bench", "bench-", "bench--press", "bénch"])
func rejectsMalformedIDs(id: String) {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises.append(Fixtures.exercise(id: id, alternatives: ["p-1", "p-2", "p-3"]))
    #expect(rules(Fixtures.library(exercises: exercises)) == [.idFormat])
}

@Test func rejectsDuplicateIDs() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises.append(Fixtures.exercise(id: "p-1", alternatives: ["p-2", "p-3", "p-4"]))
    #expect(rules(Fixtures.library(exercises: exercises)) == [.duplicateID])
}

@Test func rejectsMissingNames() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0].name.en = ""
    exercises[1].name.fr = " "
    #expect(rules(Fixtures.library(exercises: exercises)) == [.nameMissing, .nameMissing])
}

@Test func rejectsMuscleListsOutOfBounds() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0].primaryMuscles = []
    exercises[1].primaryMuscles = [.quads, .quads]
    exercises[2].secondaryMuscles = [.quads]      // chevauche le principal
    exercises[3].secondaryMuscles = [.glutes, .hamstrings, .calves, .abs, .obliques]
    #expect(rules(Fixtures.library(exercises: exercises)) == [.primaryMuscles, .primaryMuscles, .secondaryMuscles, .secondaryMuscles])
}

@Test func rejectsAlternativesOfAnotherPatternOrSelfOrUnknown() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises.append(Fixtures.exercise(id: "other", pattern: .hinge, alternatives: ["p-1", "p-2", "p-3"]))
    exercises[0].alternatives = ["p-1", "p-2", "p-3"]           // se cite lui-même
    exercises[1].alternatives = ["ghost", "p-3", "p-4"]         // inconnu
    exercises[2].alternatives = ["p-1", "p-2"]                  // pas 3
    exercises[3].alternatives = ["p-1", "p-1", "p-2"]           // doublon
    #expect(rules(Fixtures.library(exercises: exercises)).filter { $0 == .alternatives }.count == 5)
}

@Test func rejectsWrongCueOrMistakeCounts() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0] = Fixtures.exercise(id: "p-1", alternatives: ["p-2", "p-3", "p-4"], cues: 2)
    exercises[1] = Fixtures.exercise(id: "p-2", alternatives: ["p-1", "p-3", "p-4"], mistakes: 4)
    exercises[2].cues.fr[0] = String(repeating: "x", count: 91)
    #expect(rules(Fixtures.library(exercises: exercises)) == [.cues, .mistakes, .cues])
}

@Test func rejectsIncrementAndRestOutsideAllowedValues() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0] = Fixtures.exercise(id: "p-1", alternatives: ["p-2", "p-3", "p-4"], increment: 3)
    exercises[1] = Fixtures.exercise(id: "p-2", alternatives: ["p-1", "p-3", "p-4"], rest: 75)
    #expect(rules(Fixtures.library(exercises: exercises)) == [.increment, .rest])
}

@Test func rejectsUnpopulatedPattern() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[3].retired = true
    #expect(rules(Fixtures.library(exercises: exercises), ignoring: [.exerciseCount, .alternatives]) == [.patternPopulation])
}

@Test func rejectsTemplateReferencingRetiredOrUnknownExercise() {
    var exercises = Fixtures.fourExercises(pattern: .squat)
    exercises[0].retired = true
    let day = Fixtures.strengthDay(id: "a", exercises: [Fixtures.templateExercise("p-1"), Fixtures.templateExercise("ghost")])
    let template = Fixtures.template(days: [day], suggestedWeek: ["a", nil, nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let lib = Fixtures.library(exercises: exercises, templates: [template])
    #expect(rules(lib, ignoring: [.exerciseCount, .patternPopulation, .alternatives]) == [.templateExercise, .templateExercise])
}

@Test func rejectsTemplateParameterRanges() {
    let day = Fixtures.strengthDay(id: "a", exercises: [
        Fixtures.templateExercise("p-1", sets: 7), Fixtures.templateExercise("p-2", repsMin: 12, repsMax: 8),
        Fixtures.templateExercise("p-3", rpe: 7.25), Fixtures.templateExercise("p-4", rest: 100)
    ])
    let template = Fixtures.template(days: [day], suggestedWeek: ["a", nil, nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat), templates: [template])
    #expect(rules(lib) == [.templateSets, .templateReps, .templateRPE, .templateRest])
}

@Test func rejectsSupersetOfThreeOrNonConsecutive() {
    let three = Fixtures.strengthDay(id: "a", exercises: [
        Fixtures.templateExercise("p-1", superset: 1), Fixtures.templateExercise("p-2", superset: 1),
        Fixtures.templateExercise("p-3", superset: 1)
    ])
    let split = Fixtures.strengthDay(id: "b", exercises: [
        Fixtures.templateExercise("p-1", superset: 1), Fixtures.templateExercise("p-2"), Fixtures.templateExercise("p-3", superset: 1)
    ])
    let template = Fixtures.template(days: [three, split], suggestedWeek: ["a", "b", nil, nil, nil, nil, nil], sessionsPerWeek: 2)
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat), templates: [template])
    #expect(rules(lib) == [.superset, .superset])
}

@Test func rejectsRunDayWithBothTargetsOrStrengthDayWithoutExercises() {
    let both = TemplateDay(id: "r", name: LocalizedText(fr: "Course"), kind: .run,
                           run: RunTarget(type: .easy, targetMinutes: 40, targetKm: 8))
    let none = TemplateDay(id: "n", name: LocalizedText(fr: "Course"), kind: .run)
    let empty = Fixtures.strengthDay(id: "e", exercises: [])
    let template = Fixtures.template(days: [both, none, empty], suggestedWeek: ["r", "n", "e", nil, nil, nil, nil], sessionsPerWeek: 3)
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat), templates: [template])
    #expect(rules(lib) == [.runTarget, .runTarget, .runTarget])
}

@Test func rejectsSuggestedWeekMismatch() {
    let day = Fixtures.strengthDay(id: "a", exercises: [Fixtures.templateExercise("p-1")])
    let short = Fixtures.template(id: "s", days: [day], suggestedWeek: ["a", nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let unknown = Fixtures.template(id: "u", days: [day], suggestedWeek: ["zz", nil, nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let count = Fixtures.template(id: "c", days: [day], suggestedWeek: ["a", "a", nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let missing = Fixtures.template(id: "m", days: [day], suggestedWeek: [nil, nil, nil, nil, nil, nil, nil], sessionsPerWeek: 0)
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat), templates: [short, unknown, count, missing])
    #expect(rules(lib) == [.suggestedWeek, .suggestedWeek, .sessionsPerWeek, .suggestedWeek])
}

@Test func rejectsDuplicateDayIDs() {
    let day = Fixtures.strengthDay(id: "a", exercises: [Fixtures.templateExercise("p-1")])
    let template = Fixtures.template(days: [day, day], suggestedWeek: ["a", nil, nil, nil, nil, nil, nil], sessionsPerWeek: 1)
    let lib = Fixtures.library(exercises: Fixtures.fourExercises(pattern: .squat), templates: [template])
    #expect(rules(lib) == [.dayID])
}
