import Foundation
@testable import PulseDomain
import Testing

private let specExampleJSON = Data("""
{
  "id": "bench-press-barbell",
  "name": { "fr": "Développé couché à la barre", "en": "Barbell Bench Press" },
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["frontDelts", "triceps"],
  "equipment": "barbell",
  "pattern": "horizontalPush",
  "region": "upper",
  "isCompound": true,
  "isUnilateral": false,
  "loadKind": "external",
  "defaultIncrementKg": 2.5,
  "defaultRestSeconds": 120,
  "cues": { "fr": ["Omoplates serrées et abaissées sur le banc.", "Barre au niveau du bas des pectoraux, coudes à 45°.", "Pieds ancrés, pousser le sol pendant la montée."] },
  "mistakes": { "fr": ["Rebondir la barre sur la poitrine.", "Décoller les fesses du banc."] },
  "alternatives": ["chest-press-machine", "bench-press-dumbbell", "incline-chest-press-machine"]
}
""".utf8)

private let specTemplateJSON = Data("""
{
  "schemaVersion": 1,
  "id": "ppl-3",
  "name": { "fr": "PPL 3 jours", "en": "PPL 3 days" },
  "summary": { "fr": "Pousser, tirer, jambes : un cycle par semaine, idéal pour trois séances." },
  "recommendedFor": { "focus": "strength", "daysPerWeek": [3] },
  "sessionsPerWeek": 3,
  "days": [
    {
      "id": "push",
      "name": { "fr": "Push" },
      "kind": "strength",
      "exercises": [
        { "exercise": "bench-press-barbell", "sets": 4, "repsMin": 6, "repsMax": 10, "targetRPE": 8, "restSeconds": 120 },
        { "exercise": "triceps-pushdown-cable", "sets": 3, "repsMin": 10, "repsMax": 15, "targetRPE": 8, "restSeconds": 60, "supersetGroup": 1 },
        { "exercise": "wrist-curl-cable", "sets": 3, "repsMin": 12, "repsMax": 20, "targetRPE": 8, "restSeconds": 60, "supersetGroup": 1 }
      ]
    },
    {
      "id": "easy-run",
      "name": { "fr": "Course facile" },
      "kind": "run",
      "run": { "type": "easy", "targetMinutes": 40 }
    }
  ],
  "suggestedWeek": ["push", null, "pull", null, "legs", null, null]
}
""".utf8)

@Test func exerciseDecodesFromSpecExampleAndDefaultsRetired() throws {
    let exercise = try JSONDecoder().decode(Exercise.self, from: specExampleJSON)
    #expect(exercise.id == "bench-press-barbell")
    #expect(exercise.name == LocalizedText(fr: "Développé couché à la barre", en: "Barbell Bench Press"))
    #expect(exercise.primaryMuscles == [.chest])
    #expect(exercise.secondaryMuscles == [.frontDelts, .triceps])
    #expect(exercise.equipment == .barbell)
    #expect(exercise.pattern == .horizontalPush)
    #expect(exercise.region == .upper)
    #expect(exercise.isCompound && !exercise.isUnilateral)
    #expect(exercise.loadKind == .external)
    #expect(exercise.defaultIncrementKg == 2.5 && exercise.defaultRestSeconds == 120)
    #expect(exercise.cues.fr.count == 3)
    #expect(exercise.mistakes.fr.count == 2)
    #expect(exercise.alternatives == ["chest-press-machine", "bench-press-dumbbell", "incline-chest-press-machine"])
    #expect(exercise.retired == false)
}

@Test func exerciseRoundTripsThroughJSON() throws {
    var exercise = try JSONDecoder().decode(Exercise.self, from: specExampleJSON)
    exercise.retired = true
    exercise.name.en = nil
    let data = try JSONEncoder().encode(exercise)
    #expect(try JSONDecoder().decode(Exercise.self, from: data) == exercise)
}

@Test func templateDecodesNullsInSuggestedWeekAndMissingExercises() throws {
    let template = try JSONDecoder().decode(ProgramTemplate.self, from: specTemplateJSON)
    #expect(template.id == "ppl-3")
    #expect(template.recommendedFor == TemplateRecommendation(focus: .strength, daysPerWeek: [3]))
    #expect(template.suggestedWeek == ["push", nil, "pull", nil, "legs", nil, nil])
    #expect(template.days[1].kind == .run)
    #expect(template.days[1].exercises.isEmpty)
    #expect(template.days[1].run == RunTarget(type: .easy, targetMinutes: 40, targetKm: nil))
    #expect(template.days[0].exercises[1].supersetGroup == 1)
    #expect(template.days[0].exercises[0].supersetGroup == nil)
    let data = try JSONEncoder().encode(template)
    #expect(try JSONDecoder().decode(ProgramTemplate.self, from: data) == template)
}

@Test func enumCountsMatchSpec() {
    #expect(Muscle.allCases.count == 20)
    #expect(Equipment.allCases.count == 9)
    #expect(MovementPattern.allCases.count == 19)
    #expect(BodyRegion.allCases.count == 3)
    #expect(LoadKind.allCases.count == 3)
}
