import Foundation
@testable import PulseDomain
import Testing

private let m2ExerciseJSON = """
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
  "cues": { "fr": ["Omoplates serrées."] },
  "mistakes": { "fr": ["Rebondir la barre."] },
  "alternatives": ["chest-press-machine"]
}
"""

private func exerciseJSON(adding extra: String) -> Data {
    Data(m2ExerciseJSON.replacingOccurrences(of: "\n}", with: ",\n\(extra)\n}").utf8)
}

@Test func profileFirstNameRoundTripsThroughJSON() throws {
    let profile = UserProfile(firstName: "Mathéo")
    let decoded = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(profile))
    #expect(decoded == profile)
    #expect(decoded.firstName == "Mathéo")
    #expect(UserProfile().firstName == nil)
}

@Test func recoveryOriginalSessionChosenRoundTrips() throws {
    let now = Date(timeIntervalSince1970: 1)
    let recovery = DailyRecovery(day: now, score: 72, category: .normal, isEstimated: false, calibration: .ready,
                                 originalSessionChosen: true, createdAt: now, updatedAt: now)
    let decoded = try JSONDecoder().decode(DailyRecovery.self, from: JSONEncoder().encode(recovery))
    #expect(decoded == recovery)
    #expect(decoded.originalSessionChosen == true)
    let defaulted = DailyRecovery(day: now, score: 72, category: .normal, isEstimated: false, calibration: .ready,
                                  createdAt: now, updatedAt: now)
    #expect(defaulted.originalSessionChosen == nil)
}

@Test func exerciseWithoutRiskAreasDecodesEmpty() throws {
    let exercise = try JSONDecoder().decode(Exercise.self, from: Data(m2ExerciseJSON.utf8))
    #expect(exercise.riskAreas == [])
}

@Test func exerciseRiskAreasDecode() throws {
    let data = exerciseJSON(adding: "  \"riskAreas\": [\"shoulders\", \"wrists\"]")
    let exercise = try JSONDecoder().decode(Exercise.self, from: data)
    #expect(exercise.riskAreas == [.shoulders, .wrists])
}

@Test func stubNotificationAuthorizerCountsRequests() async {
    let stub = StubNotificationAuthorizer(granted: true)
    #expect(await stub.requestAuthorization() == true)
    #expect(await stub.requestCount == 1)
}

@Test func healthProfileHintsDefaultToNil() {
    let hints = HealthProfileHints()
    #expect(hints == HealthProfileHints(sex: nil, birthDate: nil, heightCm: nil, weightKg: nil))
}
