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
