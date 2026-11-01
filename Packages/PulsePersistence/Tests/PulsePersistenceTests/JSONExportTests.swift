import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

private func makeExporter(_ container: ModelContainerBox, directory: URL? = nil) -> SwiftDataExporter {
    SwiftDataExporter(container: container.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                      exerciseNames: { ["bench-press-barbell": "Développé couché à la barre"][$0] },
                      directory: directory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
}

@Test func jsonExportDecodesBackToSameData() async throws {
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container).seed(now: Fixed.t0)
    let exporter = makeExporter(box)
    let url = try await exporter.exportJSON()
    #expect(url.lastPathComponent.hasPrefix("Pulse-") && url.pathExtension == "json")
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    let snapshot = try await ExportSnapshotLoader(modelContainer: box.container).snapshot()
    #expect(doc.format == "pulse-export" && doc.formatVersion == 1 && doc.schemaVersion == 1 && doc.contentVersion == "1.0.0")
    #expect(doc.appVersion == "1.0 (1)" && doc.units.weight == "kg")
    #expect(doc.workoutSessions.count == 1 && doc.workoutSessions[0].sets.count == 9)
    // Le format est à la seconde près : on compare au document attendu passé par le même encodage.
    let metadata = ExportMetadata(appVersion: "1.0 (1)", contentVersion: "1.0.0", locale: doc.locale, exportedAt: doc.exportedAt)
    let expected = JSONExportWriter.document(from: snapshot, metadata: metadata,
                                             exerciseNames: { ["bench-press-barbell": "Développé couché à la barre"][$0] })
    let normalized = try ExportCoding.decoder().decode(ExportDocument.self, from: ExportCoding.encoder().encode(expected))
    #expect(doc == normalized)
    #expect(doc.workoutSessions[0].sets.map(\.id) == snapshot.workoutSessions[0].sets.map(\.id))
    #expect(doc.programs.count == 1 && doc.programs[0].days.count == 3 && doc.scheduledDays.count == 1)
    #expect(doc.dailyRecoveries.count == 2 && doc.checkIns.count == 1 && doc.supplements.count == 1)
    #expect(doc.supplementIntakes.count == 2 && doc.bodyMeasurements.count == 1 && doc.personalRecords.count == 1)
    #expect(doc.userExercises.count == 1 && doc.profile?.heightCm == 180)
    #expect(doc.contentExercises["bench-press-barbell"] == "Développé couché à la barre")
    #expect(doc.contentExercises.count == 1)
}

@Test func jsonExportOfEmptyStoreIsValid() async throws {
    let box = try ModelContainerBox()
    let url = try await makeExporter(box).exportJSON()
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    #expect(doc.profile == nil && doc.programs.isEmpty && doc.workoutSessions.isEmpty && doc.contentExercises.isEmpty)
}

@Test func jsonExportKeepsNameOfUnknownContentExercise() async throws {   // Review Focus 3
    let box = try ModelContainerBox()
    var session = Sample.session(sets: 1)
    session.sets[0].exercise = .content(id: "ghost")
    session.sets[0].exerciseName = "Fantôme"
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(session)
    let url = try await makeExporter(box).exportJSON()
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    #expect(doc.workoutSessions[0].sets[0].exerciseName == "Fantôme")
    #expect(doc.contentExercises["ghost"] == nil)
}

@Test func jsonExportExcludesLogicallyDeleted() async throws {
    let box = try ModelContainerBox()
    let repo = SwiftDataWorkoutRepository(modelContainer: box.container)
    let kept = Sample.session(sets: 1)
    let deleted = Sample.session(sets: 1)
    try await repo.save(kept)
    try await repo.save(deleted)
    try await repo.delete(id: deleted.id)
    let url = try await makeExporter(box).exportJSON()
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    #expect(doc.workoutSessions.map(\.id) == [kept.id])
}

@Test func exportDirectoryIsEmptiedBeforeEachExport() async throws {
    let box = try ModelContainerBox()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = makeExporter(box, directory: directory)
    _ = try await exporter.exportJSON()
    _ = try await exporter.exportJSON()
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
}
