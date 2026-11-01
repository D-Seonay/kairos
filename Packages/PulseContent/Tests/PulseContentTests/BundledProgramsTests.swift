import PulseContent
import PulseDomain
import Testing

private struct Row: Equatable {
    let day: String
    let exercise: String
    let sets: Int
    let min: Int
    let max: Int
    let rpe: Double
    let rest: Int
    let superset: Int?

    init(_ day: String, _ exercise: String, _ sets: Int, _ min: Int, _ max: Int, _ rpe: Double, _ rest: Int, _ superset: Int? = nil) {
        self.day = day
        self.exercise = exercise
        self.sets = sets
        self.min = min
        self.max = max
        self.rpe = rpe
        self.rest = rest
        self.superset = superset
    }
}

@Test func fiveTemplatesInOrderAndValid() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    #expect(lib.programTemplates.map(\.id) == ["ppl-3", "ppl-6", "upper-lower", "full-body", "runner-strength"])
    let issues = ContentValidator.issues(in: lib)
    #expect(issues.isEmpty, Comment(rawValue: issues.map(\.description).joined(separator: "\n")))
}

@Test func ppl3MatchesMatheoRoutineExactly() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    let template = try #require(lib.programTemplate(id: "ppl-3"))
    #expect(template.recommendedFor == TemplateRecommendation(focus: .strength, daysPerWeek: [3]))
    #expect(template.sessionsPerWeek == 3)
    #expect(template.suggestedWeek == ["push", nil, "pull", nil, "legs", nil, nil])
    let rows: [Row] = [
        Row("push", "bench-press-barbell", 4, 6, 10, 8, 120), Row("push", "chest-press-machine", 3, 8, 12, 8, 90),
        Row("push", "pec-deck-machine", 3, 10, 15, 8, 60), Row("push", "triceps-pushdown-cable", 3, 10, 15, 8, 60, 1),
        Row("push", "wrist-curl-cable", 3, 12, 20, 8, 60, 1), Row("push", "crunch-machine", 3, 12, 20, 8, 60),
        Row("pull", "lat-pulldown-machine", 4, 8, 12, 8, 90), Row("pull", "seated-row-machine-iso-lateral", 3, 8, 12, 8, 90),
        Row("pull", "lateral-raise-machine", 3, 12, 15, 8, 60), Row("pull", "preacher-curl-machine", 3, 10, 12, 8, 60),
        Row("pull", "hammer-curl-dumbbell", 3, 10, 12, 8, 60),
        Row("legs", "leg-press-machine", 4, 8, 12, 8, 120), Row("legs", "lying-leg-curl-machine", 3, 10, 12, 8, 90),
        Row("legs", "hip-abduction-machine", 3, 12, 15, 8, 60), Row("legs", "hip-adduction-machine", 3, 12, 15, 8, 60),
        Row("legs", "seated-calf-raise-machine", 4, 12, 15, 8, 60), Row("legs", "leg-extension-machine", 3, 12, 15, 8, 60)
    ]
    let flat = template.days.flatMap { day in
        day.exercises.map { Row(day.id, $0.exercise, $0.sets, $0.repsMin, $0.repsMax, $0.targetRPE, $0.restSeconds, $0.supersetGroup) }
    }
    #expect(flat == rows)
}

@Test func otherTemplatesFollowTheirFrames() throws {
    let lib = try ContentLibrary.load(from: ContentLibrary.resourceBundle)
    let ppl6 = try #require(lib.programTemplate(id: "ppl-6"))
    #expect(ppl6.days.count == 6 && ppl6.sessionsPerWeek == 6 && ppl6.suggestedWeek[6] == nil)
    #expect(ppl6.days.map(\.id) == ["push", "pull", "legs", "push-2", "pull-2", "legs-2"])
    let upperLower = try #require(lib.programTemplate(id: "upper-lower"))
    #expect(upperLower.days.count == 4 && upperLower.recommendedFor.focus == .balanced)
    #expect(upperLower.suggestedWeek == ["upper-a", "lower-a", nil, "upper-b", "lower-b", nil, nil])
    let fullBody = try #require(lib.programTemplate(id: "full-body"))
    #expect(fullBody.days.count == 3 && fullBody.days.allSatisfy { $0.exercises.count == 6 })
    #expect(fullBody.suggestedWeek == ["full-a", nil, "full-b", nil, "full-c", nil, nil])
    let runner = try #require(lib.programTemplate(id: "runner-strength"))
    #expect(runner.recommendedFor.focus == .endurance && runner.sessionsPerWeek == 5)
    #expect(runner.days.filter { $0.kind == .run }.map { $0.run?.type } == [.easy, .intervals, .long])
    #expect(runner.suggestedWeek == ["easy-run", "strength-a", nil, "intervals", "strength-b", nil, "long-run"])
}
