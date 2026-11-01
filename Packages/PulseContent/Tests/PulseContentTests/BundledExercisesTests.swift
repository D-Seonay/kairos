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
    expectCounts([.horizontalPush: 6, .chestFly: 4, .verticalPush: 4, .shoulderIsolation: 5, .verticalPull: 4, .horizontalPull: 5], in: lib)
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
    expectCounts([.elbowFlexion: 5, .elbowExtension: 5, .forearm: 4, .squat: 5, .lunge: 4, .hinge: 5], in: lib)
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
    #expect(lib.exercises.count == 84)
    #expect(lib.activeExercises.count == 84)
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
