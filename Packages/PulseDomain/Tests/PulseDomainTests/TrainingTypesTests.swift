import Foundation
@testable import PulseDomain
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> Bool {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data) == value
}

@Test func defaultProfileMatchesSpec() {
    let profile = UserProfile()
    #expect(profile.focus == 0.5)
    #expect(profile.trainingDaysPerWeek == 3)
    #expect(profile.availablePlatesKg == [25, 20, 15, 10, 5, 2.5, 1.25])
    #expect(profile.barWeightKg == 20)
    #expect(profile.upperIncrementKg == 2.5 && profile.lowerIncrementKg == 5)
    #expect(profile.defaultRestSeconds == 90)
    #expect(profile.adaptationEnabled && profile.autoWarmupEnabled)
    #expect(profile.sex == .unspecified && profile.theme == .amber && profile.weightUnit == .kg)
    #expect(profile.strengthLevel == .beginner && profile.runningLevel == .beginner)
    #expect(profile.onboardingCompletedAt == nil && profile.activeProgramID == nil)
}

@Test func programFromTemplateCopiesDaysAndWeek() throws {
    let template = ProgramTemplate(
        id: "ppl-3", name: LocalizedText(fr: "PPL 3 jours"), summary: LocalizedText(fr: "Résumé"),
        recommendedFor: TemplateRecommendation(focus: .strength, daysPerWeek: [3]), sessionsPerWeek: 2,
        days: [
            TemplateDay(id: "push", name: LocalizedText(fr: "Push"), kind: .strength, exercises: [
                TemplateExercise(exercise: "bench-press-barbell", sets: 4, repsMin: 6, repsMax: 10,
                                 targetRPE: 8, restSeconds: 120),
                TemplateExercise(exercise: "wrist-curl-cable", sets: 3, repsMin: 12, repsMax: 20,
                                 targetRPE: 8, restSeconds: 60, supersetGroup: 1)
            ]),
            TemplateDay(id: "easy-run", name: LocalizedText(fr: "Course facile"), kind: .run,
                        run: RunTarget(type: .easy, targetMinutes: 40))
        ],
        suggestedWeek: ["push", nil, "easy-run", nil, nil, nil, nil])
    let now = Date(timeIntervalSince1970: 0)
    let program = Program(template: template, now: now)
    #expect(program.templateID == "ppl-3")
    #expect(program.name == "PPL 3 jours")
    #expect(program.sessionsPerWeek == 2)
    #expect(program.createdAt == now && program.updatedAt == now)
    #expect(program.days.count == 2)
    #expect(program.days.map(\.order) == [0, 1])
    #expect(program.days[0].name == "Push" && program.days[0].kind == .strength)
    #expect(program.days[0].exercises.map(\.order) == [0, 1])
    #expect(program.days[0].exercises[0].exercise == .content(id: "bench-press-barbell"))
    #expect(program.days[0].exercises[1].supersetGroup == 1)
    #expect(program.days[1].kind == .run && program.days[1].runType == .easy && program.days[1].runTargetMinutes == 40)
    #expect(program.weekLayout == [program.days[0].id, nil, program.days[1].id, nil, nil, nil, nil])
}

@Test func trainingTypesRoundTrip() throws {
    var profile = UserProfile()
    profile.restWeekdays = [.sunday]
    profile.painAreas = [.knees, .lowerBack]
    profile.antiInterferenceRulesDisabled = [.fullRestDay]
    profile.birthDate = Date(timeIntervalSince1970: 1_000)
    #expect(try roundTrip(profile))

    let day = RoutineDay(id: UUID(), order: 0, name: "Legs", kind: .strength, exercises: [
        RoutineExercise(id: UUID(), order: 0, exercise: .user(id: UUID()), sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: 90)
    ])
    let program = Program(id: UUID(), name: "Custom", templateID: nil, sessionsPerWeek: 1,
                          weekLayout: [nil, day.id, nil, nil, nil, nil, nil], isArchived: false, days: [day],
                          createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(program))

    let exercise = UserExercise(id: UUID(), name: "Rowing machine du coin", primaryMuscle: .lats, secondaryMuscles: [.biceps],
                                equipment: .machine, pattern: .horizontalPull, region: .upper, isUnilateral: false,
                                defaultIncrementKg: 2.5, defaultRestSeconds: 90, isArchived: false,
                                createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(exercise))
}
