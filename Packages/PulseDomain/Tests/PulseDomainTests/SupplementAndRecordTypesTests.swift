import Foundation
@testable import PulseDomain
import Testing

private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> Bool {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(T.self, from: data) == value
}

private let t1 = Date(timeIntervalSince1970: 1)
private let t2 = Date(timeIntervalSince1970: 2)

@Test func supplementTypesRoundTrip() throws {
    let supplement = Supplement(id: UUID(), name: "Créatine", form: .powder, dose: 5, unit: .gram, timing: .afterWorkout,
                                timeOfDayMinutes: nil, days: .custom, customWeekdays: [.monday, .thursday], stockDoses: 60,
                                lowStockThreshold: 10, reminderEnabled: true, healthKitType: nil, isArchived: false, order: 0,
                                createdAt: t1, updatedAt: t2)
    #expect(try roundTrip(supplement))
    let intake = SupplementIntake(id: UUID(), supplementID: supplement.id, takenAt: t1, dose: 5, writtenToHealthKit: false,
                                  healthKitUUID: nil, createdAt: t1, updatedAt: t2)
    #expect(try roundTrip(intake))
    let measurement = BodyMeasurement(id: UUID(), date: t1, weightKg: 78.4, bodyFatPercent: 15.2, source: .appleHealth,
                                      healthKitUUID: "ABC", createdAt: t1, updatedAt: t2)
    #expect(try roundTrip(measurement))
    let record = PersonalRecord(id: UUID(), exercise: .content(id: "bench-press-barbell"), exerciseName: "Développé couché",
                                kind: .repsAtWeight, value: 10, weightKg: 80, date: t1, sessionID: UUID(), setID: UUID(),
                                createdAt: t1, updatedAt: t2)
    #expect(try roundTrip(record))
}

@Test func cachedSampleRoundTrip() throws {
    let sample = CachedHealthSample(id: UUID(), kind: .sleep, start: t1, end: t2, value: nil, sleepStage: .deep,
                                    distanceMeters: nil, averageHeartRate: nil, durationMinutes: nil,
                                    healthKitUUID: "X", sourceBundleID: "com.fitbit.FitbitMobile", fetchedAt: t2)
    #expect(try roundTrip(sample))
    let snapshot = ActiveSessionSnapshot(id: UUID(), startedAt: t1, updatedAt: t2, payload: Data([1, 2, 3]))
    #expect(try roundTrip(snapshot))
}

@Test func storeTableFileNamesAreSnakeCase() {
    #expect(StoreTable.routineExercises.fileName == "routine_exercises")
    #expect(StoreTable.profile.fileName == "profile")
    #expect(StoreTable.allCases.count == 17)
    #expect(StoreTable.exported.count == 14)
    #expect(!StoreTable.exported.contains(.cachedHealthSamples))
    #expect(!StoreTable.exported.contains(.healthQueryAnchors))
    #expect(!StoreTable.exported.contains(.activeSessionSnapshots))
}

@Test func stubHealthEraserCountsAndThrows() async throws {
    let eraser = StubHealthEraser()
    try await eraser.deleteAllSamplesWrittenByPulse()
    try await eraser.deleteAllSamplesWrittenByPulse()
    #expect(eraser.callCount == 2)
    struct Boom: Error {}
    let failing = StubHealthEraser(error: Boom())
    await #expect(throws: Boom.self) { try await failing.deleteAllSamplesWrittenByPulse() }
    #expect(failing.callCount == 1)
}
