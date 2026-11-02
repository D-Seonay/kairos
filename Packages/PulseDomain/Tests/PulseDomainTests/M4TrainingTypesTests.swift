import Foundation
@testable import PulseDomain
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data)
}

private extension Date {
    static let t0 = Date(timeIntervalSince1970: 1_794_700_000)
}

private enum Fixtures {
    /// L'entrée `bench-press-barbell` de la spec M2 §4.1, au format du contenu 1.1.0 (sans `tracksDuration`).
    static let benchPressJSON = """
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
      "cues": { "fr": ["Omoplates serrées et abaissées sur le banc."] },
      "mistakes": { "fr": ["Rebondir la barre sur la poitrine."] },
      "alternatives": ["chest-press-machine", "bench-press-dumbbell"],
      "retired": false
    }
    """
}

@Test func repRangeUsesThePerSetTargetWhenPresent() {
    var exercise = RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: 3, repsMin: 4, repsMax: 12,
                                   targetRPE: 8, restSeconds: 120)
    #expect(exercise.repRange(forSet: 2) == 4...12)
    exercise.setTargets = [SetTarget(repsMin: 10, repsMax: 12), SetTarget(repsMin: 4, repsMax: 6), SetTarget(repsMin: 4, repsMax: 6)]
    #expect(exercise.repRange(forSet: 0) == 10...12)
    #expect(exercise.repRange(forSet: 1) == 4...6)
    #expect(exercise.repRange(forSet: 5) == 4...12)
}

@Test func exerciseWithoutTracksDurationDecodesAsReps() throws {
    // JSON d'un exercice du contenu sans la clé tracksDuration (format du contenu 1.1.0).
    let exercise = try JSONDecoder().decode(Exercise.self, from: Data(Fixtures.benchPressJSON.utf8))
    #expect(exercise.tracksDuration == false)
}

@Test func m4TypesRoundTripThroughJSON() throws {
    let note = ExerciseNote(exercise: .content(id: "pec-deck-machine"), text: "Siège cran 4")
    let settings = ExerciseSettings(exercise: .user(id: UUID()), incrementKg: 3.5, warmupSetCount: 0, createdAt: .t0, updatedAt: .t0)
    #expect(try roundTrip(note) == note)
    #expect(try roundTrip(settings) == settings)
    #expect(SessionSource(rawValue: "hevy") == .hevy)
}
