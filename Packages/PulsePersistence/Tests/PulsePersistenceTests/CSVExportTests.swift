import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func csvArchiveContainsEveryTableAndRoundTripsQuotedNote() async throws {   // Review Focus 2
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    let zip = try await exporter.exportCSVArchive()
    #expect(zip.pathExtension == "zip" && zip.lastPathComponent.hasSuffix("-csv.zip"))
    let size = try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int ?? 0
    #expect(size > 100)
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    let files = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
    #expect(files == Set(StoreTable.exported.map { $0.fileName + ".csv" }).union(["README.txt"]))
    let sets = try String(contentsOf: folder.appendingPathComponent("workout_sets.csv"), encoding: .utf8)
    #expect(sets.split(separator: "\n").count == 10)
    let sessions = try String(contentsOf: folder.appendingPathComponent("workout_sessions.csv"), encoding: .utf8)
    #expect(sessions.contains("\"Dos ok, \"\"lourd\"\" aujourd'hui\""))
}

@Test func csvExportOfEmptyStoreHasHeadersOnly() async throws {
    let box = try ModelContainerBox()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    for table in StoreTable.exported {
        let text = try String(contentsOf: folder.appendingPathComponent(table.fileName + ".csv"), encoding: .utf8)
        #expect(text.split(separator: "\n").count == 1, Comment(rawValue: table.rawValue))
    }
}

@Test func csvHasNewColumns() async throws {
    let box = try ModelContainerBox()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    let profile = try String(contentsOf: folder.appendingPathComponent("profile.csv"), encoding: .utf8)
    #expect(profile.hasPrefix("id,first_name,"))
    let recoveries = try String(contentsOf: folder.appendingPathComponent("daily_recoveries.csv"), encoding: .utf8)
    #expect(recoveries.contains("frozen_at,original_session_chosen"))
}

@Test func csvCarriesExerciseSettingsAndTheV3Columns() async throws {
    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    let snapshot = try await ExportSnapshotLoader(modelContainer: box.container).snapshot()
    let metadata = ExportMetadata(appVersion: "1.0 (1)", contentVersion: "1.0.0", locale: "fr_FR", exportedAt: Fixed.t0)
    let document = JSONExportWriter.document(from: snapshot, metadata: metadata, exerciseNames: { _ in nil })
    let tables = CSVTables.tables(from: document, timeZone: Fixed.calendar.timeZone)
    let settings = try #require(tables[.exerciseSettings])
    #expect(settings.header == ["id", "content_exercise_id", "user_exercise_id", "increment_kg", "warmup_set_count",
                                "created_at", "updated_at"])
    #expect(settings.rows.count == 1)
    #expect(try #require(tables[.workoutSessions]).header.contains("exercise_notes"))
    #expect(try #require(tables[.workoutSets]).header.contains("duration_seconds"))
    #expect(try #require(tables[.routineExercises]).header.contains("set_targets"))
    let userHeader = try #require(tables[.userExercises]).header
    #expect(["load_kind", "is_compound", "tracks_duration"].allSatisfy(userHeader.contains))
    #expect(CSVTables.readme(for: document).contains("exercise_settings.csv : réglages par exercice (incrément, échauffement)"))
}

@Test func csvIncludesLocalHealthValues() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    try await SwiftDataWorkoutRepository(modelContainer: box.container).save(Sample.importedRun())
    try await SwiftDataBodyMeasurementRepository(modelContainer: box.container).save(Sample.measurement())
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    func lines(_ name: String) throws -> [Substring] {
        try String(contentsOf: folder.appendingPathComponent(name + ".csv"), encoding: .utf8).split(separator: "\n")
    }
    let recoveries = try lines("daily_recoveries")
    #expect(recoveries.count == 2 && recoveries[1].contains(",50,"))
    let sessions = try lines("workout_sessions")
    #expect(sessions.count == 2 && sessions[1].contains("RUN"))
    let measurements = try lines("body_measurements")
    #expect(measurements.count == 2 && measurements[1].contains("ABC"))
}

private struct PhotoArchive {
    let folder: URL
    let photos: [(photo: SessionPhoto, image: PhotoImage)]
    let removed: SessionPhoto
}

private func photoArchive() async throws -> PhotoArchive {
    let box = try ModelContainerBox()
    let repo = SwiftDataSessionPhotoRepository(modelContainer: box.container)
    let sessionID = try await Sample.savedSession(in: box, id: try #require(UUID(uuidString: "ABCDEF12-0000-0000-0000-000000000001")))
    var photos: [(photo: SessionPhoto, image: PhotoImage)] = []
    for order in 0..<2 {
        let photo = Sample.sessionPhoto(sessionID: sessionID, order: order, createdAt: Fixed.t0)
        let image = Sample.photoImage(seed: UInt8(order + 1))
        try await repo.add(photo, image: image)
        photos.append((photo, image))
    }
    let removed = Sample.sessionPhoto(sessionID: sessionID, order: 2)
    try await repo.add(removed, image: Sample.photoImage(seed: 9))
    try await repo.delete(photoID: removed.id)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory, timeZone: Fixed.calendar.timeZone)
    _ = try await exporter.exportCSVArchive()
    return PhotoArchive(folder: try #require(exporter.lastCSVDirectory(in: directory)), photos: photos, removed: removed)
}

@Test func csvArchiveContainsSessionPhotos() async throws {
    let archive = try await photoArchive()
    let names = try FileManager.default.contentsOfDirectory(atPath: archive.folder.appendingPathComponent("photos").path).sorted()
    #expect(names == ["2026-11-15-abcdef12-1.jpg", "2026-11-15-abcdef12-2.jpg"])
    let table = try String(contentsOf: archive.folder.appendingPathComponent("session_photos.csv"), encoding: .utf8)
    let lines = table.split(separator: "\n").map(String.init)
    #expect(lines.first == "id,session_id,order,created_at,file")
    #expect(lines.count == 3)
    #expect(lines[1].hasSuffix(",photos/2026-11-15-abcdef12-1.jpg") && lines[2].hasSuffix(",photos/2026-11-15-abcdef12-2.jpg"))
    #expect(lines[1].hasPrefix(archive.photos[0].photo.id.uuidString + ",ABCDEF12-0000-0000-0000-000000000001,0,"))
    #expect(!table.contains(archive.removed.id.uuidString))
    let readme = try String(contentsOf: archive.folder.appendingPathComponent("README.txt"), encoding: .utf8)
    #expect(readme.contains("session_photos.csv") && readme.contains("photos/"))
}

@Test func csvArchiveCopiesPhotoBytesUnchanged() async throws {
    let archive = try await photoArchive()
    for (index, entry) in archive.photos.enumerated() {
        let url = archive.folder.appendingPathComponent("photos/2026-11-15-abcdef12-\(index + 1).jpg")
        #expect(try Data(contentsOf: url) == entry.image.image)
    }
}

@Test func csvArchiveWithoutPhotosHasNoPhotosFolder() async throws {
    let box = try ModelContainerBox()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("photos").path))
}

/// Deux appareils peuvent donner le même rang à deux photos de la même séance le même jour : deux fichiers, chacun nommé dans sa ligne.
@Test func csvArchiveKeepsBothPhotosWhenNamesCollide() async throws {
    let box = try ModelContainerBox()
    let repo = SwiftDataSessionPhotoRepository(modelContainer: box.container)
    let sessionID = try await Sample.savedSession(in: box, id: try #require(UUID(uuidString: "ABCDEF12-0000-0000-0000-000000000001")))
    let first = Sample.sessionPhoto(sessionID: sessionID, order: 0, createdAt: Fixed.t0)
    let second = Sample.sessionPhoto(sessionID: sessionID, order: 0, createdAt: Fixed.t1)
    try await repo.add(first, image: Sample.photoImage(seed: 1))
    try await repo.add(second, image: Sample.photoImage(seed: 2))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                     exerciseNames: { _ in nil }, directory: directory, timeZone: Fixed.calendar.timeZone)
    _ = try await exporter.exportCSVArchive()
    let folder = try #require(exporter.lastCSVDirectory(in: directory))
    let names = try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("photos").path)
    #expect(names.count == 2 && Set(names).count == 2)
    let table = try String(contentsOf: folder.appendingPathComponent("session_photos.csv"), encoding: .utf8)
    let rows = table.split(separator: "\n").dropFirst().map { $0.split(separator: ",").map(String.init) }
    #expect(rows.count == 2)
    for (photo, seed) in [(first, UInt8(1)), (second, UInt8(2))] {
        let row = try #require(rows.first { $0[0] == photo.id.uuidString })
        let bytes = try Data(contentsOf: folder.appendingPathComponent(try #require(row.last)))
        #expect(bytes == Sample.photoImage(seed: seed).image)
    }
    let suffix = second.id.uuidString.lowercased().prefix(4)
    #expect(try #require(rows.first { $0[0] == second.id.uuidString }).last == "photos/2026-11-15-abcdef12-1-\(suffix).jpg")
}
