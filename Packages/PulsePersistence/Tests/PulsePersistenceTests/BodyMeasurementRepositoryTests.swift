import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func bodyMeasurementsByDate() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    let later = Sample.measurement(date: Fixed.t0.addingTimeInterval(86_400))
    let earlier = Sample.measurement(date: Fixed.t0)
    let outside = Sample.measurement(date: Fixed.t0.addingTimeInterval(86_400 * 9))
    for measurement in [later, earlier, outside] { try await repo.save(measurement) }
    #expect(try await repo.measurements(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(86_400 * 7)).map(\.id) == [earlier.id, later.id])
    var updated = earlier
    updated.weightKg = 77
    try await repo.save(updated)
    try await repo.delete(id: later.id)
    let all = try await repo.measurements(from: .distantPast, to: .distantFuture)
    #expect(all.map(\.id) == [earlier.id, outside.id] && all[0].weightKg == 77)
}

// MARK: - Mesures importées d'Apple Health : magasin local

private func counts(_ container: ModelContainer) throws -> (synced: Int, local: Int) {
    let context = ModelContext(container)
    return (try context.fetchCount(FetchDescriptor<StoredBodyMeasurement>()),
            try context.fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()))
}

private func manualCopy(of measurement: BodyMeasurement) -> BodyMeasurement {
    var copy = measurement
    copy.id = UUID()
    copy.source = .manual
    copy.healthKitUUID = nil
    return copy
}

@Test func healthMeasurementLivesOnlyInTheLocalStore() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    try await repo.save(Sample.measurement())
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 0 && stored.local == 1)
}

@Test func manualMeasurementLivesOnlyInTheSyncedStore() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    try await repo.save(manualCopy(of: Sample.measurement()))
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 1 && stored.local == 0)
}

@Test func measurementsMergeBothStoresByDateThenCreation() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    let health = Sample.measurement(date: Fixed.t0)
    var manual = manualCopy(of: Sample.measurement(date: Fixed.t0))
    manual.createdAt = Fixed.t0
    let earlier = manualCopy(of: Sample.measurement(date: Fixed.t0.addingTimeInterval(-86_400)))
    for measurement in [health, manual, earlier] { try await repo.save(measurement) }
    let all = try await repo.measurements(from: .distantPast, to: .distantFuture)
    #expect(all.map(\.id) == [earlier.id, manual.id, health.id])
}

@Test func deletingAHealthMeasurementMarksItDeleted() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    let health = Sample.measurement()
    try await repo.save(health)
    try await repo.delete(id: health.id)
    #expect(try await repo.measurements(from: .distantPast, to: .distantFuture).isEmpty)
    let local = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredImportedBodyMeasurement>())
    #expect(local.count == 1 && local[0].deletedAt != nil)
}

@Test func changingSourceMovesTheMeasurementBetweenStores() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    var measurement = manualCopy(of: Sample.measurement())
    try await repo.save(measurement)
    measurement.source = .appleHealth
    try await repo.save(measurement)
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 0 && stored.local == 1)
}

/// Avec la clé unique, réimporter une pesée supprimée réécrit la même ligne au lieu d'en créer une seconde.
@Test func reimportingADeletedWeighInReusesItsRow() async throws {
    let repo = SwiftDataBodyMeasurementRepository(modelContainer: try TestContainer.make())
    let weighIn = Sample.measurement()
    try await repo.save(weighIn)
    try await repo.delete(id: weighIn.id)
    try await repo.save(weighIn)
    #expect(try ModelContext(repo.modelContainer).fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()) == 1)
    #expect(try await repo.measurements(from: .distantPast, to: .distantFuture).map(\.id) == [weighIn.id])
}
