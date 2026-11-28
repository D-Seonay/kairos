import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

private func makeExporter(_ container: ModelContainerBox, directory: URL? = nil) -> SwiftDataExporter {
    SwiftDataExporter(container: container.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                      exerciseNames: { ["bench-press-barbell": "Développé couché à la barre"][$0] },
                      directory: directory ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
}

@Test func jsonExportDecodesBackToSameData() async throws {
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    let exporter = makeExporter(box)
    let url = try await exporter.exportJSON()
    #expect(url.lastPathComponent.hasPrefix("Pulse-") && url.pathExtension == "json")
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    let snapshot = try await ExportSnapshotLoader(modelContainer: box.container).snapshot()
    #expect(doc.format == "pulse-export" && doc.formatVersion == 1 && doc.schemaVersion == 3 && doc.contentVersion == "1.0.0")
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
    #expect(doc.userExercises.count == 1 && doc.profile?.heightCm == 180 && doc.exerciseSettings.count == 1)
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

@Test func exportCarriesExerciseSettingsAndTheV3Fields() async throws {
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    var session = Sample.session(startedAt: Fixed.t1, sets: 2)
    session.exerciseNotes = [ExerciseNote(exercise: .content(id: "bench-press-barbell"), text: "Coudes serrés")]
    session.sets[1].durationSeconds = 45
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(session)
    let url = try await makeExporter(box).exportJSON()
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    #expect(doc.schemaVersion == 3)
    #expect(doc.exerciseSettings.count == 1)
    #expect(doc.workoutSessions.flatMap(\.sets).contains { $0.durationSeconds == 45 })
    #expect(doc.workoutSessions.flatMap(\.exerciseNotes).map(\.text) == ["Coudes serrés"])
}

@Test func exportIncludesLocalHealthValues() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(Sample.importedRun())
    try await SwiftDataBodyMeasurementRepository(modelContainer: box.container).save(Sample.measurement())
    let url = try await makeExporter(box).exportJSON()
    let json = try String(contentsOf: url, encoding: .utf8)
    #expect(json.contains("\"sdnnMs\" : 50"))
    #expect(json.contains("\"healthKitUUID\" : \"RUN\""))
    #expect(json.contains("\"healthKitUUID\" : \"ABC\""))
}

/// Les tracés vivants partent dans l'export ; une course Pulse y retrouve sa FC et son RPE estimé, lus dans le résumé local.
@Test func exportCarriesRunTracksAndPulseRunHeartRate() async throws {
    let box = try ModelContainerBox()
    let run = Sample.pulseRun()
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(run)
    let tracks = SwiftDataRunTrackRepository(modelContainer: box.container)
    try await tracks.save(Sample.runTrack(sessionID: run.id))
    let deleted = Sample.runTrack()
    try await tracks.save(deleted)
    try await tracks.delete(sessionID: deleted.id)
    let url = try await makeExporter(box).exportJSON()
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: url))
    #expect(doc.runTracks.map(\.id) == [run.id])
    #expect(doc.runTracks.first?.points.count == 4 && doc.runTracks.first?.splits.count == 2)
    #expect(doc.workoutSessions.map(\.averageHeartRate) == [150] && doc.workoutSessions.map(\.estimatedRPE) == [8])
}

/// Le JSON liste les photos vivantes, jamais leurs octets.
@Test func jsonExportListsPhotosWithoutImages() async throws {
    let box = try ModelContainerBox()
    let photos = SwiftDataSessionPhotoRepository(modelContainer: box.container)
    let sessionID = try await Sample.savedSession(in: box)
    let kept = Sample.sessionPhoto(sessionID: sessionID, order: 0)
    let removed = Sample.sessionPhoto(sessionID: sessionID, order: 1)
    try await photos.add(kept, image: Sample.photoImage(seed: 5))
    try await photos.add(removed, image: Sample.photoImage(seed: 6))
    try await photos.delete(photoID: removed.id)
    let url = try await makeExporter(box).exportJSON()
    let data = try Data(contentsOf: url)
    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: data)
    #expect(doc.sessionPhotos.map(\.id) == [kept.id])
    #expect(doc.sessionPhotos.first?.sessionID == sessionID && doc.sessionPhotos.first?.order == 0)
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(json.contains("\"sessionPhotos\""))
    let base64Run = try Regex("[A-Za-z0-9+/=]{1000,}")
    #expect(json.firstMatch(of: base64Run) == nil)
}

/// Une photo sans séance n'est pas exportée : aucun identifiant de séance inventé.
@Test func exportSkipsPhotosWithoutASession() async throws {
    let box = try ModelContainerBox()
    let photos = SwiftDataSessionPhotoRepository(modelContainer: box.container)
    let sessionID = try await Sample.savedSession(in: box)
    let kept = Sample.sessionPhoto(sessionID: sessionID, order: 0)
    let orphan = Sample.sessionPhoto(sessionID: sessionID, order: 1)
    try await photos.add(kept, image: Sample.photoImage(seed: 1))
    try await photos.add(orphan, image: Sample.photoImage(seed: 2))
    let context = ModelContext(box.container)
    let orphanID = orphan.id
    try #require(try context.fetch(FetchDescriptor<StoredSessionPhoto>(predicate: #Predicate { $0.id == orphanID })).first).sessionID = nil
    try context.save()
    let snapshot = try await ExportSnapshotLoader(modelContainer: box.container).snapshot()
    #expect(snapshot.sessionPhotos.map(\.id) == [kept.id])
}

/// Une photo dont la séance n'existe pas (séance abandonnée, supprimée) n'apparaît nulle part (spec §5.1) : ni dans le JSON, ni dans
/// le CSV, ni dans le dossier photos/ de l'archive.
@Test func exportSkipsPhotosOfAMissingSession() async throws {
    let box = try ModelContainerBox()
    let photos = SwiftDataSessionPhotoRepository(modelContainer: box.container)
    let kept = Sample.sessionPhoto(sessionID: try await Sample.savedSession(in: box), order: 0)
    let stray = Sample.sessionPhoto(sessionID: UUID(), order: 0)
    try await photos.add(kept, image: Sample.photoImage(seed: 1))
    try await photos.add(stray, image: Sample.photoImage(seed: 2))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let exporter = makeExporter(box, directory: directory)

    let doc = try ExportCoding.decoder().decode(ExportDocument.self, from: Data(contentsOf: try await exporter.exportJSON()))
    #expect(doc.sessionPhotos.map(\.id) == [kept.id])

    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    let table = try String(contentsOf: folder.appendingPathComponent("session_photos.csv"), encoding: .utf8)
    #expect(table.contains(kept.id.uuidString) && !table.contains(stray.id.uuidString))
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("photos").path)
    #expect(files.count == 1)
    let bytes = try Data(contentsOf: folder.appendingPathComponent("photos").appendingPathComponent(try #require(files.first)))
    #expect(bytes == Sample.photoImage(seed: 1).image)
}

/// Deux appareils hors ligne ont chacun écrit le score et le check-in du même jour : l'export n'en garde qu'un de chaque, le plus
/// récent, comme l'app.
@Test func exportKeepsOneRecoveryAndOneCheckInPerDay() async throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let day = Fixed.calendar.startOfDay(for: Fixed.t0)
    for (score, updatedAt) in [(55.0, Fixed.t2), (65.0, Fixed.t1)] {
        var recovery = Sample.recovery(day: day, score: score)
        recovery.id = UUID()
        recovery.updatedAt = updatedAt
        let row = StoredDailyRecovery(recovery)
        row.dayKey = "2026-11-21"
        context.insert(row)
        var checkIn = Sample.checkIn(day: day)
        checkIn.id = UUID()
        checkIn.score = score
        checkIn.updatedAt = updatedAt
        let checkInRow = StoredCheckIn(checkIn)
        checkInRow.dayKey = "2026-11-21"
        context.insert(checkInRow)
    }
    try context.save()
    let snapshot = try await ExportSnapshotLoader(modelContainer: box.container).snapshot()
    #expect(snapshot.dailyRecoveries.map(\.score) == [55])
    #expect(snapshot.checkIns.map(\.score) == [55])
}
