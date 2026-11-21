import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

// Chaque test écrit des lignes synchronisées « à l'ancienne », comme avant M8a : les dépôts n'écrivent plus comme ça.

/// Score synchronisé d'avant M8a : les six valeurs brutes sont encore dans la ligne.
private func legacyRecovery(sdnnMs: Double = 50) -> StoredDailyRecovery {
    let recovery = Sample.recovery(day: Fixed.calendar.startOfDay(for: Fixed.t0))
    let row = StoredDailyRecovery(recovery)
    row.sdnnMs = sdnnMs
    row.sdnnBaselineMs = recovery.sdnnBaselineMs
    row.restingHeartRate = recovery.restingHeartRate
    row.restingHeartRateBaseline = recovery.restingHeartRateBaseline
    row.asleepMinutes = recovery.asleepMinutes
    row.deepMinutes = recovery.deepMinutes
    return row
}

/// Course Apple Santé d'avant M8a, gardée dans le magasin synchronisé.
private func legacyRun(startedAt: Date = Fixed.t0) -> StoredWorkoutSession {
    StoredWorkoutSession(Sample.importedRun(startedAt: startedAt))   // source `appleHealth`
}

private func hasNoRawValue(_ row: StoredDailyRecovery) -> Bool {
    row.sdnnMs == nil && row.sdnnBaselineMs == nil && row.restingHeartRate == nil && row.restingHeartRateBaseline == nil
        && row.asleepMinutes == nil && row.deepMinutes == nil
}

private func syncedHealthRuns(_ context: ModelContext) throws -> Int {
    let health = SessionSource.appleHealth.rawValue
    return try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate { $0.source == health }))
}

@Test func movesRawNightValuesToTheDevice() async throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    context.insert(legacyRecovery())
    try context.save()
    let moved = try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate()
    #expect(moved)
    let check = ModelContext(box.container)
    let synced = try #require(try check.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(hasNoRawValue(synced))
    #expect(synced.score == 72 && synced.hrvScore == 80)
    let read = try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar)
        .dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(read.count == 1 && read[0].sdnnMs == 50 && read[0].restingHeartRateBaseline == 50 && read[0].deepMinutes == 80)
}

@Test func localReadingWinsOverAnOldSyncedValue() async throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let row = legacyRecovery(sdnnMs: 50)
    context.insert(row)
    var newer = row.toDomain()
    newer.sdnnMs = 55
    context.insert(StoredRecoveryReading(day: row.day, from: newer, at: Fixed.t2))
    try context.save()
    _ = try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate()
    let check = ModelContext(box.container)
    let readings = try check.fetch(FetchDescriptor<StoredRecoveryReading>())
    #expect(readings.count == 1 && readings.first?.sdnnMs == 55)
    let synced = try #require(try check.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(hasNoRawValue(synced))
}

@Test func movesImportedRunsAndDropsDeletedOnes() async throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let alive = legacyRun()
    let deleted = legacyRun(startedAt: Fixed.t1)
    deleted.deletedAt = Fixed.t2
    context.insert(alive)
    context.insert(deleted)
    try context.save()
    let moved = try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate()
    #expect(moved)
    let check = ModelContext(box.container)
    #expect(try syncedHealthRuns(check) == 0)
    let imported = try check.fetch(FetchDescriptor<StoredImportedWorkout>())
    #expect(imported.map(\.id) == [alive.id])
    #expect(imported.first?.distanceMeters == 8_000 && imported.first?.averageHeartRate == 151)
    #expect(imported.first?.updatedAt == Fixed.t2 && imported.first?.createdAt == Fixed.t1)
}

@Test func doesNotDuplicateAnAlreadyMovedRun() async throws {   // Review Focus 3
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let run = legacyRun()
    context.insert(run)
    context.insert(StoredImportedWorkout(run.toDomain()))
    try context.save()
    _ = try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate()
    let check = ModelContext(box.container)
    #expect(try syncedHealthRuns(check) == 0)
    let imported = try check.fetch(FetchDescriptor<StoredImportedWorkout>())
    #expect(imported.map(\.id) == [run.id])
}

@Test func movesHealthWeighInsAndKeepsManualOnes() async throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let health = StoredBodyMeasurement(Sample.measurement())
    var manualValue = Sample.measurement(date: Fixed.t1)
    manualValue.source = .manual
    manualValue.healthKitUUID = nil
    let manual = StoredBodyMeasurement(manualValue)
    context.insert(health)
    context.insert(manual)
    try context.save()
    let moved = try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate()
    #expect(moved)
    let check = ModelContext(box.container)
    let synced = try check.fetch(FetchDescriptor<StoredBodyMeasurement>())
    #expect(synced.map(\.id) == [manual.id])
    let imported = try check.fetch(FetchDescriptor<StoredImportedBodyMeasurement>())
    #expect(imported.map(\.id) == [health.id])
    #expect(imported.first?.weightKg == 78.4 && imported.first?.bodyFatPercent == 15.2)
}

@Test func relocatingTwiceChangesNothing() async throws {   // Review Focus 4
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    context.insert(legacyRecovery())
    context.insert(legacyRun())
    context.insert(StoredBodyMeasurement(Sample.measurement()))
    try context.save()
    let relocation = SwiftDataHealthDataRelocation(modelContainer: box.container)
    #expect(try await relocation.relocate())
    let firstStamp = try #require(try ModelContext(box.container).fetch(FetchDescriptor<StoredDailyRecovery>()).first).updatedAt
    #expect(try await relocation.relocate() == false)
    let check = ModelContext(box.container)
    let synced = try #require(try check.fetch(FetchDescriptor<StoredDailyRecovery>()).first)
    #expect(synced.updatedAt == firstStamp && synced.updatedAt == Fixed.t2)
    #expect(try check.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 1)
    #expect(try check.fetchCount(FetchDescriptor<StoredImportedWorkout>()) == 1)
    #expect(try check.fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()) == 1)
}

@Test func nothingToMoveReturnsFalse() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(Sample.session())
    #expect(try await SwiftDataHealthDataRelocation(modelContainer: box.container).relocate() == false)
}
