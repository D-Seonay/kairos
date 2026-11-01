import Foundation
@testable import PulseDomain
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> Bool {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data) == value
}

private func makeSet(order: Int) -> WorkoutSet {
    WorkoutSet(id: UUID(), order: order, exercise: .content(id: "plank"), exerciseName: "Planche", setType: .working)
}

@Test func missedSetIsDerived() {
    var set = makeSet(order: 1)
    set.plannedReps = 8
    set.actualReps = 3
    #expect(set.isMissed)
    set.actualReps = 8
    #expect(!set.isMissed)
    set.plannedReps = nil
    #expect(!set.isMissed)
    set.plannedReps = 8
    set.actualReps = nil
    #expect(!set.isMissed)
}

@Test func sessionWithSetsRoundTrips() throws {
    var replaced = makeSet(order: 2)
    replaced.replacedExercise = .content(id: "bench-press-barbell")
    replaced.replacementReason = .machineBusy
    replaced.supersetGroup = 1
    replaced.completedAt = Date(timeIntervalSince1970: 100)
    let session = WorkoutSession(
        id: UUID(), startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 3_600), kind: .strength,
        source: .pulse, status: .completed, programID: UUID(), routineDayID: UUID(), title: "Push",
        appliedAdjustments: [SessionAdjustment(kind: .volume, reason: "Fatigue modérée", value: -0.2)],
        refusedAdjustments: [SessionAdjustment(kind: .rpeCap, reason: "Plafond RPE 7,5", value: 7.5)],
        overallRPE: 8, note: "Dos ok", tonnageKg: 1_200, durationMinutes: 60, distanceMeters: nil, averageHeartRate: nil,
        estimatedRPE: nil, healthKitUUID: nil, sets: [makeSet(order: 1), replaced],
        createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(session))
    #expect(session.sets[1].replacementReason == .machineBusy)
}

@Test func scheduledDayAndRecoveryRoundTrip() throws {
    let day = ScheduledDay(id: UUID(), date: Date(timeIntervalSince1970: 0), programID: UUID(), routineDayID: UUID(), title: "Legs",
                           kind: .strength, status: .planned, movedFromDate: Date(timeIntervalSince1970: -86_400),
                           moveReason: .antiInterferenceAfterHeavyLegs, moveReasonText: "Fractionné vendredi", validatedManually: false,
                           sessionID: nil, createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(day))
    let recovery = DailyRecovery(id: UUID(), day: Date(timeIntervalSince1970: 0), score: 72, category: .normal, isEstimated: false,
                                 hrvScore: 80, restingHeartRateScore: 60, sleepScore: 70, sdnnMs: 50, sdnnBaselineMs: 48,
                                 restingHeartRate: 52, restingHeartRateBaseline: 50, asleepMinutes: 420, deepMinutes: 80,
                                 missingFactors: [.hrv], calibration: .calibrating(nights: 7),
                                 adjustments: [SessionAdjustment(kind: .rest, reason: "Repos +45 s", value: 45)], frozenAt: nil,
                                 createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(recovery))
}

@Test func checkInRoundTrip() throws {
    let checkIn = CheckIn(id: UUID(), day: Date(timeIntervalSince1970: 0), answers: CheckInAnswers(sleep: 3, pain: 4, motivation: 2),
                          score: 77.5, createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2))
    #expect(try roundTrip(checkIn))
}
