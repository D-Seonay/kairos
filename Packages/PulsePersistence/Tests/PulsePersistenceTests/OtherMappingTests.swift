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
    #expect(PersistenceStack.localModels.count == 8)
    #expect(PersistenceStack.syncedModels.count == 17)
    #expect(PulseSchemaV1.models.count == 17 && PulseSchemaV2.models.count == 17 && PulseSchemaV3.models.count == 18)
    #expect(PulseSchemaV4.models.count == 21 && PulseSchemaV5.models.count == 24
        && PulseSchemaV6.models.count == 25 && PulseSchemaV7.models.count == 25)
}

/// Une récupération sans ses six valeurs brutes, qui ne passent plus par le magasin synchronisé.
private func withoutRawValues(_ recovery: DailyRecovery) -> DailyRecovery {
    var bare = recovery
    bare.sdnnMs = nil
    bare.sdnnBaselineMs = nil
    bare.restingHeartRate = nil
    bare.restingHeartRateBaseline = nil
    bare.asleepMinutes = nil
    bare.deepMinutes = nil
    return bare
}

@Test func newM3FieldsRoundTripThroughStoredModels() {
    var recovery = Sample.recovery()
    recovery.originalSessionChosen = false
    #expect(StoredDailyRecovery(recovery).toDomain() == withoutRawValues(recovery))
    let profile = UserProfile(firstName: "Mathéo", createdAt: Fixed.t0, updatedAt: Fixed.t1)
    #expect(StoredProfile(profile).toDomain() == profile)
}

@Test func recoveryCheckInSupplementRoundTrip() throws {
    let recovery = Sample.recovery(estimated: true)
    #expect(StoredDailyRecovery(recovery).toDomain() == withoutRawValues(recovery))
    var full = Sample.recovery()
    full.calibration = .ready
    full.frozenAt = Fixed.t1
    #expect(StoredDailyRecovery(full).toDomain() == withoutRawValues(full))
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

@Test func clearHealthValuesNilsTheSixRawFields() {
    let row = StoredDailyRecovery(Sample.recovery())
    row.sdnnMs = 50
    row.deepMinutes = 80
    row.clearHealthValues()
    #expect(row.sdnnMs == nil && row.sdnnBaselineMs == nil && row.restingHeartRate == nil)
    #expect(row.restingHeartRateBaseline == nil && row.asleepMinutes == nil && row.deepMinutes == nil)
    #expect(row.score == 72)
}
