import PulseContent
import PulseDomain
import Testing

private let sliceRules: Set<ContentRule> = [.exerciseCount, .patternPopulation]

private func expectCounts(_ expected: [MovementPattern: Int], in lib: ContentLibrary) {
    for (pattern, count) in expected {
        #expect(lib.exercises.filter { $0.pattern == pattern }.count == count, Comment(rawValue: pattern.rawValue))
    }
}

@Test func upperBodyPushPullExercisesArePresentAndValid() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    expectCounts([.horizontalPush: 7, .chestFly: 4, .verticalPush: 4, .shoulderIsolation: 5, .verticalPull: 5, .horizontalPull: 5], in: lib)
    #expect(lib.exercise(id: "bench-press-barbell")?.name.fr == "Développé couché à la barre")
    #expect(lib.exercise(id: "chest-press-machine")?.equipment == .machine)
    #expect(lib.exercise(id: "lat-pulldown-machine")?.pattern == .verticalPull)
    #expect(lib.exercise(id: "push-up")?.loadKind == .bodyweight)
    #expect(lib.exercise(id: "assisted-pull-up-machine")?.loadKind == .assisted)
    let issues = ContentValidator.issues(in: lib, ignoring: sliceRules)
    #expect(issues.isEmpty, Comment(rawValue: issues.map(\.description).joined(separator: "\n")))
}

@Test func armsAndLowerBodyExercisesArePresentAndValid() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    expectCounts([.elbowFlexion: 6, .elbowExtension: 8, .forearm: 5, .squat: 5, .lunge: 4, .hinge: 7], in: lib)
    #expect(lib.exercise(id: "leg-press-machine")?.region == .lower)
    #expect(lib.exercise(id: "leg-press-machine")?.defaultIncrementKg == 5)
    #expect(lib.exercise(id: "hammer-curl-dumbbell")?.name.fr == "Curl marteau aux haltères")
    #expect(lib.exercise(id: "wrist-curl-cable")?.pattern == .forearm)
    #expect(lib.exercise(id: "dips")?.loadKind == .bodyweight)
    let issues = ContentValidator.issues(in: lib, ignoring: sliceRules)
    #expect(issues.isEmpty, Comment(rawValue: issues.map(\.description).joined(separator: "\n")))
}

@Test func bundledCatalogIsCompleteAndValid() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    let templateRules: Set<ContentRule> = [.templateExercise, .templateSets, .templateReps, .templateRPE, .templateRest,
                                           .superset, .runTarget, .suggestedWeek, .sessionsPerWeek, .dayID]
    let issues = ContentValidator.issues(in: lib, ignoring: templateRules)
    #expect(issues.isEmpty, Comment(rawValue: issues.map(\.description).joined(separator: "\n")))
    #expect(lib.exercises.count == 93)
    #expect(lib.activeExercises.count == 93)
    for pattern in MovementPattern.allCases {
        #expect(lib.exercises.filter { $0.pattern == pattern }.count >= 4, Comment(rawValue: pattern.rawValue))
    }
}

@Test func matheoPPLExercisesArePresent() throws {
    let ids = ["bench-press-barbell", "chest-press-machine", "pec-deck-machine", "triceps-pushdown-cable", "wrist-curl-cable",
               "crunch-machine", "lat-pulldown-machine", "seated-row-machine-iso-lateral", "lateral-raise-machine",
               "preacher-curl-machine", "hammer-curl-dumbbell", "leg-press-machine", "lying-leg-curl-machine",
               "hip-abduction-machine", "hip-adduction-machine", "seated-calf-raise-machine", "leg-extension-machine"]
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    for id in ids { #expect(lib.exercise(id: id) != nil, Comment(rawValue: id)) }
}

@Test func unknownExerciseResolvesToNil() throws {
    #expect(try ContentLibrary.load(from: ContentLibrary.resourceBundle).exercise(id: "does-not-exist") == nil)
}

@Test func riskAreasMatchTheSpecTable() {
    let expected: [String: [PainArea]] = [
        "overhead-press-barbell": [.shoulders], "seated-dumbbell-shoulder-press": [.shoulders], "shoulder-press-machine": [.shoulders],
        "arnold-press": [.shoulders], "dips": [.shoulders], "dumbbell-fly": [.shoulders],
        "deadlift-barbell": [.lowerBack], "romanian-deadlift-barbell": [.lowerBack], "barbell-row": [.lowerBack],
        "back-squat-barbell": [.lowerBack], "front-squat-barbell": [.lowerBack, .wrists],
        "sissy-squat": [.knees], "walking-lunge-dumbbell": [.knees], "bulgarian-split-squat": [.knees],
        "reverse-lunge-dumbbell": [.knees], "leg-extension-machine": [.knees], "single-leg-extension-machine": [.knees],
        "push-up": [.wrists], "barbell-curl": [.wrists], "wrist-curl-barbell": [.wrists], "reverse-wrist-curl-barbell": [.wrists],
        "assisted-dips-machine": [.shoulders], "back-extension-machine": [.lowerBack], "hyperextension": [.lowerBack],
        "seated-wrist-curl-dumbbell": [.wrists]
    ]
    let tagged = ContentLibrary.bundled.exercises.filter { !$0.riskAreas.isEmpty }
    let actual = Dictionary(uniqueKeysWithValues: tagged.map { ($0.id, $0.riskAreas) })
    #expect(actual == expected)
}

@Test func machinePreacherCurlPrefersCableBeforeEZBar() {
    #expect(ContentLibrary.bundled.exercise(id: "preacher-curl-machine")?.alternatives
        == ["cable-curl", "ez-bar-preacher-curl", "hammer-curl-dumbbell"])
}

@Test func catalogHas93ValidExercises() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.exercises.count == 93)
    #expect(lib.contentVersion == "1.2.0")
    #expect(ContentValidator.issues(in: lib).isEmpty)
    #expect(lib.exercise(id: "assisted-dips-machine")?.loadKind == .assisted)
    #expect(lib.exercise(id: "hyperextension")?.loadKind == .bodyweight)
    #expect(["plank", "side-plank", "copenhagen-plank"].allSatisfy { lib.exercise(id: $0)?.tracksDuration == true })
    #expect(lib.exercises.filter(\.tracksDuration).count == 3)
}

private struct AddedExercise {
    var id: String
    var pattern: MovementPattern
    var equipment: Equipment
    var isCompound: Bool
    var increment: Double
    var rest: Int
}

private func added(_ id: String, _ pattern: MovementPattern, _ equipment: Equipment, _ isCompound: Bool,
                   _ dosing: (increment: Double, rest: Int)) -> AddedExercise {
    AddedExercise(id: id, pattern: pattern, equipment: equipment, isCompound: isCompound, increment: dosing.increment, rest: dosing.rest)
}

@Test func theNineAddedExercisesFollowTheSpecTable() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    let expected = [
        added("assisted-dips-machine", .elbowExtension, .machine, true, (2.5, 90)),
        added("close-grip-lat-pulldown-cable", .verticalPull, .cable, true, (2.5, 90)),
        added("dumbbell-curl", .elbowFlexion, .dumbbell, false, (2.5, 60)),
        added("rope-pushdown-cable", .elbowExtension, .cable, false, (2.5, 60)),
        added("triceps-extension-machine", .elbowExtension, .machine, false, (2.5, 60)),
        added("decline-chest-press-machine", .horizontalPush, .machine, true, (2.5, 90)),
        added("back-extension-machine", .hinge, .machine, false, (2.5, 90)),
        added("hyperextension", .hinge, .bodyweight, false, (2.5, 90)),
        added("seated-wrist-curl-dumbbell", .forearm, .dumbbell, false, (1.25, 60))
    ]
    for item in expected {
        let exercise = try #require(lib.exercise(id: item.id), Comment(rawValue: item.id))
        #expect(exercise.pattern == item.pattern && exercise.equipment == item.equipment, Comment(rawValue: item.id))
        #expect(exercise.isCompound == item.isCompound && exercise.defaultIncrementKg == item.increment, Comment(rawValue: item.id))
        #expect(exercise.defaultRestSeconds == item.rest, Comment(rawValue: item.id))
        #expect(!exercise.name.fr.isEmpty && exercise.name.en?.isEmpty == false, Comment(rawValue: item.id))
    }
    #expect(lib.exercise(id: "assisted-dips-machine")?.alternatives
        == ["dips", "triceps-extension-machine", "close-grip-bench-press"])
    #expect(lib.exercise(id: "seated-wrist-curl-dumbbell")?.alternatives
        == ["wrist-curl-cable", "wrist-curl-barbell", "reverse-wrist-curl-barbell"])
}
