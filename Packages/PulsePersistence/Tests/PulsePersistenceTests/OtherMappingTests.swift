import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func localModelsLiveInTheLocalConfiguration() throws {
    let container = try TestContainer.make()
    let context = ModelContext(container)
    context.insert(StoredCachedHealthSample(Sample.cachedSample()))
    context.insert(StoredActiveSessionSnapshot(Sample.snapshot()))
    context.insert(StoredHealthQueryAnchor(kind: .sleep, anchorData: Data([9])))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<StoredCachedHealthSample>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<StoredHealthQueryAnchor>()) == 1)
    #expect(PersistenceStack.localModels.count == 3)
    #expect(PersistenceStack.syncedModels.count == 14)
    #expect(PulseSchemaV1.models.count == 17)
}

@Test func recoveryCheckInSupplementRoundTrip() throws {
    let recovery = Sample.recovery(estimated: true)
    #expect(StoredDailyRecovery(recovery).toDomain() == recovery)
    var full = Sample.recovery()
    full.calibration = .ready
    full.frozenAt = Fixed.t1
    #expect(StoredDailyRecovery(full).toDomain() == full)
    let checkIn = Sample.checkIn()
    #expect(StoredCheckIn(checkIn).toDomain() == checkIn)
    let supplement = Sample.supplement()
    #expect(StoredSupplement(supplement).toDomain() == supplement)
    var bare = supplement
    bare.customWeekdays = []
    bare.stockDoses = nil
    bare.lowStockThreshold = nil
    #expect(StoredSupplement(bare).toDomain() == bare)
    let intake = Sample.intake(supplementID: supplement.id)
    #expect(StoredSupplementIntake(intake).toDomain() == intake)
}

@Test func bodyRecordCacheSnapshotRoundTrip() throws {
    let measurement = Sample.measurement()
    #expect(StoredBodyMeasurement(measurement).toDomain() == measurement)
    let record = Sample.record(exercise: .user(id: UUID()))
    #expect(StoredPersonalRecord(record).toDomain() == record)
    let sleep = Sample.cachedSample(kind: .sleep)
    #expect(StoredCachedHealthSample(sleep).toDomain() == sleep)
    let snapshot = Sample.snapshot()
    #expect(StoredActiveSessionSnapshot(snapshot).toDomain() == snapshot)
}
