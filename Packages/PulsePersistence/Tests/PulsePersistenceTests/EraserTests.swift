// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

private struct EraseFixture {
    let box: ModelContainerBox
    let suite: String
    let defaults: UserDefaults
    let exports: URL
    let health: StubHealthEraser

    init(health: StubHealthEraser = StubHealthEraser()) throws {
        box = try ModelContainerBox()
        suite = "pulse.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "onboardingCompleted")
        exports = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try "x".write(to: exports.appendingPathComponent("Pulse.json"), atomically: true, encoding: .utf8)
        self.health = health
    }

    func eraser() -> SwiftDataEraser {
        SwiftDataEraser(container: box.container, defaultsSuite: suite, defaultsDomain: suite, healthEraser: health,
                        notifications: nil, widgets: nil, exportsDirectory: exports)
    }

    func counts() async throws -> [StoreTable: Int] {
        try await SwiftDataStoreInspector(container: box.container, cloudEnabled: false).counts()
    }
}

@Test func eraseEmptiesEveryTableDefaultsAndExports() async throws {
    let fixture = try EraseFixture()
    try await SampleDataSeeder(container: fixture.box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    try await SwiftDataActiveSessionStore(modelContainer: fixture.box.container).save(Sample.snapshot())
    try await SwiftDataHealthSampleCache(modelContainer: fixture.box.container).saveAnchor(Data([1]), for: .sleep)
    #expect(try await fixture.counts().values.contains { $0 > 0 })
    #expect(try await fixture.counts()[.exerciseSettings] == 1)
    try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: false))
    let counts = try await fixture.counts()
    #expect(counts.count == StoreTable.allCases.count && counts.values.allSatisfy { $0 == 0 })
    #expect(counts[.exerciseSettings] == 0)
    #expect(fixture.defaults.object(forKey: "onboardingCompleted") == nil)
    #expect(!FileManager.default.fileExists(atPath: fixture.exports.path))
    #expect(fixture.health.callCount == 0)
}

@Test func eraseCallsHealthEraserOnlyWhenRequested() async throws {
    let fixture = try EraseFixture()
    try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: true))
    #expect(fixture.health.callCount == 1)
}

@Test func healthEraseFailureStillWipesLocalStore() async throws {   // Review Focus 4
    struct Boom: Error {}
    let fixture = try EraseFixture(health: StubHealthEraser(error: Boom()))
    try await SampleDataSeeder(container: fixture.box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    await #expect(throws: Boom.self) {
        try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: true))
    }
    #expect(try await fixture.counts().values.allSatisfy { $0 == 0 })
    #expect(fixture.defaults.object(forKey: "onboardingCompleted") == nil)
}

@Test func notificationsAreCancelledWhenProvided() async throws {
    final class Canceller: NotificationCanceling, @unchecked Sendable {
        var calls = 0
        func cancelAllScheduled() async { calls += 1 }
    }
    let fixture = try EraseFixture()
    let canceller = Canceller()
    let eraser = SwiftDataEraser(container: fixture.box.container, defaultsSuite: fixture.suite, defaultsDomain: fixture.suite,
                                 healthEraser: fixture.health, notifications: canceller, widgets: nil,
                                 exportsDirectory: fixture.exports)
    try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
    #expect(canceller.calls == 1)
}

@Test func eraseClearsTheWidgetSnapshot() async throws {
    let fixture = try EraseFixture()
    let widgets = StubWidgetPublisher()
    let eraser = SwiftDataEraser(container: fixture.box.container, defaultsSuite: fixture.suite, defaultsDomain: fixture.suite,
                                 healthEraser: fixture.health, notifications: nil, widgets: widgets,
                                 exportsDirectory: fixture.exports)
    try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
    #expect(await widgets.clearCount == 1)
}

@Test func healthEraseFailureStillClearsTheWidgetSnapshot() async throws {
    struct Boom: Error {}
    let fixture = try EraseFixture(health: StubHealthEraser(error: Boom()))
    let widgets = StubWidgetPublisher()
    let eraser = SwiftDataEraser(container: fixture.box.container, defaultsSuite: fixture.suite, defaultsDomain: fixture.suite,
                                 healthEraser: fixture.health, notifications: nil, widgets: widgets,
                                 exportsDirectory: fixture.exports)
    await #expect(throws: Boom.self) {
        try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: true))
    }
    #expect(await widgets.clearCount == 1)
}
// swiftlint:enable force_unwrapping

/// Le miroir CloudKit n'exporte que ce qui passe par l'historique persistant : chaque enregistrement
/// synchronisé effacé doit y laisser une suppression (spec M2 §7.2, suppression enregistrement par enregistrement).
@Test func eraseRecordsADeleteInHistoryForEverySyncedRecord() async throws {
    let fixture = try EraseFixture()
    try await SampleDataSeeder(container: fixture.box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    let before = try await fixture.counts()
    let syncedCount = StoreTable.exported.reduce(0) { $0 + (before[$1] ?? 0) }
    let syncedEntities = Set(PersistenceStack.syncedModels.map { String(describing: $0) })
    try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: false))
    let context = ModelContext(fixture.box.container)
    let changes = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).flatMap(\.changes)
    let deletes = changes.compactMap { change -> String? in
        guard case .delete(let deletion) = change else { return nil }
        return deletion.changedPersistentIdentifier.entityName
    }
    #expect(syncedCount == 32, "jeu d'exemple : 32 enregistrements synchronisés sur les 15 tables")
    #expect(deletes.filter { syncedEntities.contains($0) }.count == syncedCount)
}

@Test func eraseWipesLocalHealthModels() async throws {
    let fixture = try EraseFixture()
    let container = fixture.box.container
    try await SwiftDataRecoveryRepository(modelContainer: container, calendar: Fixed.calendar).save(Sample.recovery())
    try await SwiftDataWorkoutRepository(modelContainer: container).save(Sample.importedRun())
    try await SwiftDataBodyMeasurementRepository(modelContainer: container).save(Sample.measurement())
    let before = ModelContext(container)
    #expect(try before.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 1)
    #expect(try before.fetchCount(FetchDescriptor<StoredImportedWorkout>()) == 1)
    #expect(try before.fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()) == 1)
    try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: false))
    let context = ModelContext(container)
    #expect(try context.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<StoredImportedWorkout>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()) == 0)
}

@Test func wipeAllRemovesRunModels() async throws {
    let container = try TestContainer.make()
    let run = Sample.pulseRun()
    try await SwiftDataWorkoutRepository(modelContainer: container).save(run)
    try await SwiftDataRunTrackRepository(modelContainer: container).save(Sample.runTrack(sessionID: run.id))
    try await SwiftDataRunDraftStore(modelContainer: container).save(Sample.runDraft())
    let context = ModelContext(container)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunTrack>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunDraft>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunHealthSummary>()) == 1)
    try await StoreWiper(modelContainer: container).wipeAll()
    let check = ModelContext(container)
    #expect(try check.fetchCount(FetchDescriptor<StoredRunTrack>()) == 0)
    #expect(try check.fetchCount(FetchDescriptor<StoredRunDraft>()) == 0)
    #expect(try check.fetchCount(FetchDescriptor<StoredRunHealthSummary>()) == 0)
}

@Test func wipeAllRemovesSessionPhotos() async throws {
    let container = try TestContainer.make()
    let photos = SwiftDataSessionPhotoRepository(modelContainer: container)
    let sessionID = UUID()
    try await photos.add(Sample.sessionPhoto(sessionID: sessionID, order: 0), image: Sample.photoImage(seed: 1))
    try await photos.add(Sample.sessionPhoto(sessionID: sessionID, order: 1), image: Sample.photoImage(seed: 2))
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredSessionPhoto>()) == 2)
    try await StoreWiper(modelContainer: container).wipeAll()
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredSessionPhoto>()) == 0)
}

/// Les photos de corps vivent hors du magasin : l'effacement total doit les vider elles aussi, même si Santé échoue.
@Test func eraserDeletesBodyPhotos() async throws {
    let fixture = try EraseFixture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-body-\(UUID().uuidString)", isDirectory: true)
    let store = FileBodyPhotoStore(directory: directory)
    try await store.save(BodyPhoto(id: UUID(), pose: .front, takenAt: Fixed.t0, createdAt: Fixed.t0), image: Sample.photoImage(seed: 1))
    try await store.save(BodyPhoto(id: UUID(), pose: .back, takenAt: Fixed.t1, createdAt: Fixed.t1), image: Sample.photoImage(seed: 2))
    #expect(try await store.photos().count == 2)
    let eraser = SwiftDataEraser(container: fixture.box.container, defaultsSuite: fixture.suite, defaultsDomain: fixture.suite,
                                 healthEraser: fixture.health, notifications: nil, widgets: nil, exportsDirectory: fixture.exports,
                                 bodyPhotos: store)
    try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
    #expect(try await store.photos().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: directory.path))
}
