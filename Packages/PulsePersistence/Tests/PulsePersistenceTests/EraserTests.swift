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
                        notifications: nil, exportsDirectory: exports)
    }

    func counts() async throws -> [StoreTable: Int] {
        try await SwiftDataStoreInspector(container: box.container, cloudEnabled: false).counts()
    }
}

@Test func eraseEmptiesEveryTableDefaultsAndExports() async throws {
    let fixture = try EraseFixture()
    try await SampleDataSeeder(container: fixture.box.container).seed(now: Fixed.t0)
    try await SwiftDataActiveSessionStore(modelContainer: fixture.box.container).save(Sample.snapshot())
    try await SwiftDataHealthSampleCache(modelContainer: fixture.box.container).saveAnchor(Data([1]), for: .sleep)
    #expect(try await fixture.counts().values.contains { $0 > 0 })
    try await fixture.eraser().eraseEverything(options: EraseOptions(includeAppleHealth: false))
    let counts = try await fixture.counts()
    #expect(counts.count == StoreTable.allCases.count && counts.values.allSatisfy { $0 == 0 })
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
    try await SampleDataSeeder(container: fixture.box.container).seed(now: Fixed.t0)
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
                                 healthEraser: fixture.health, notifications: canceller, exportsDirectory: fixture.exports)
    try await eraser.eraseEverything(options: EraseOptions(includeAppleHealth: false))
    #expect(canceller.calls == 1)
}
// swiftlint:enable force_unwrapping

/// Le miroir CloudKit n'exporte que ce qui passe par l'historique persistant : chaque enregistrement
/// synchronisé effacé doit y laisser une suppression (spec M2 §7.2, suppression enregistrement par enregistrement).
@Test func eraseRecordsADeleteInHistoryForEverySyncedRecord() async throws {
    let fixture = try EraseFixture()
    try await SampleDataSeeder(container: fixture.box.container).seed(now: Fixed.t0)
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
    #expect(syncedCount == 31, "jeu d'exemple : 31 enregistrements synchronisés sur les 14 tables")
    #expect(deletes.filter { syncedEntities.contains($0) }.count == syncedCount)
}
