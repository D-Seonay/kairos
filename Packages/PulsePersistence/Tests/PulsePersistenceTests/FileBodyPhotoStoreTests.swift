import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

/// Midi UTC du jour donné : le même jour local dans tous les fuseaux, quel que soit celui de la machine de test.
private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Fixed.t0
}

private func bodyPhoto(_ pose: BodyPose = .front, takenAt: Date = noonUTC(2026, 8, 1)) -> BodyPhoto {
    BodyPhoto(id: UUID(), pose: pose, takenAt: takenAt, createdAt: Fixed.t0)
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("pulse-body-\(UUID().uuidString)", isDirectory: true)
}

private func files(in directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
}

private func indexEntries(in directory: URL) throws -> [BodyPhoto] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([BodyPhoto].self, from: Data(contentsOf: directory.appendingPathComponent("index.json")))
}

@Suite struct FileBodyPhotoStoreTests {
    @Test func savedPhotoIsReadBack() async throws {
        let store = FileBodyPhotoStore(directory: temporaryDirectory())
        let photo = bodyPhoto(.side)
        let image = Sample.photoImage(seed: 7)
        try await store.save(photo, image: image)
        #expect(try await store.photos() == [photo])
        #expect(try await store.image(of: photo.id) == image)
    }

    @Test func saveWithSameIDReplaces() async throws {
        let store = FileBodyPhotoStore(directory: temporaryDirectory())
        let photo = bodyPhoto(.front)
        try await store.save(photo, image: Sample.photoImage(seed: 1))
        var moved = photo
        moved.pose = .back
        let newImage = Sample.photoImage(seed: 2)
        try await store.save(moved, image: newImage)
        #expect(try await store.photos() == [moved])
        #expect(try await store.image(of: photo.id) == newImage)
    }

    @Test func deleteRemovesFilesAndEntry() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        let kept = bodyPhoto(.front)
        let removed = bodyPhoto(.back)
        try await store.save(kept, image: Sample.photoImage(seed: 1))
        try await store.save(removed, image: Sample.photoImage(seed: 2))
        try await store.delete(photoID: removed.id)
        let remaining = files(in: directory)
        #expect(!remaining.contains("\(removed.id.uuidString).jpg") && !remaining.contains("\(removed.id.uuidString)-thumb.jpg"))
        #expect(try indexEntries(in: directory) == [kept])
        #expect(try await store.image(of: removed.id) == nil)
        try await store.delete(photoID: UUID())   // une photo inconnue n'est pas une erreur
    }

    @Test func deleteAllRemovesTheDirectory() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 1))
        try await store.deleteAll()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(try await store.photos().isEmpty)
        try await store.deleteAll()   // déjà vide : rien à faire
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 2))   // le dossier se recrée
        #expect(try await store.photos().count == 1)
    }

    @Test func directoryIsExcludedFromBackup() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 1))
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        try await store.deleteAll()
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 1))
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func missingFileDropsItsIndexEntry() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        let kept = bodyPhoto(.front)
        let lost = bodyPhoto(.side)
        try await store.save(kept, image: Sample.photoImage(seed: 1))
        try await store.save(lost, image: Sample.photoImage(seed: 2))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("\(lost.id.uuidString).jpg"))
        #expect(try await store.photos() == [kept])
        #expect(try indexEntries(in: directory) == [kept])
    }

    @Test func pruningAnEntryAlsoRemovesItsThumbnail() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        let lost = bodyPhoto(.side)
        try await store.save(lost, image: Sample.photoImage(seed: 2))
        try FileManager.default.removeItem(at: directory.appendingPathComponent("\(lost.id.uuidString).jpg"))
        #expect(try await store.photos().isEmpty)
        #expect(!files(in: directory).contains("\(lost.id.uuidString)-thumb.jpg"))
    }

    @Test func orphanFilesAreRemoved() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        let kept = bodyPhoto(.front)
        try await store.save(kept, image: Sample.photoImage(seed: 1))
        // Des fichiers sans entrée d'index (échec d'écriture, suppression interrompue) et un fichier étranger.
        let orphan = UUID()
        try Data([1]).write(to: directory.appendingPathComponent("\(orphan.uuidString).jpg"))
        try Data([2]).write(to: directory.appendingPathComponent("\(orphan.uuidString)-thumb.jpg"))
        try Data([3]).write(to: directory.appendingPathComponent("notes.txt"))
        #expect(try await store.photos() == [kept])
        let expected = ["\(kept.id.uuidString)-thumb.jpg", "\(kept.id.uuidString).jpg", "index.json", "notes.txt"]
        #expect(files(in: directory) == expected.sorted())
    }

    @Test func orphansFromAnUnreadableIndexAreSweptOnceItIsRewritten() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        let old = bodyPhoto(.front)
        try await store.save(old, image: Sample.photoImage(seed: 1))
        try "x".write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        // Index illisible : rien n'est balayé, les fichiers restent là.
        #expect(try await store.photos().isEmpty)
        #expect(files(in: directory).contains("\(old.id.uuidString).jpg"))
        // Un `save` réécrit l'index ; les fichiers de l'ancienne photo deviennent des orphelins balayés.
        let fresh = bodyPhoto(.back)
        try await store.save(fresh, image: Sample.photoImage(seed: 2))
        #expect(try await store.photos() == [fresh])
        #expect(!files(in: directory).contains("\(old.id.uuidString).jpg"))
    }

    @Test func unreadableIndexStartsEmpty() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "x".write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        let store = FileBodyPhotoStore(directory: directory)
        #expect(try await store.photos().isEmpty)
        let photo = bodyPhoto()
        try await store.save(photo, image: Sample.photoImage(seed: 3))
        #expect(try await store.photos() == [photo])
    }

    @Test func exportArchiveNamesFilesByDayAndPose() async throws {
        let store = FileBodyPhotoStore(directory: temporaryDirectory())
        try await store.save(bodyPhoto(.front, takenAt: noonUTC(2026, 8, 1)), image: Sample.photoImage(seed: 1))
        try await store.save(bodyPhoto(.back, takenAt: noonUTC(2026, 10, 28)), image: Sample.photoImage(seed: 2))
        try await store.save(bodyPhoto(.side, takenAt: noonUTC(2026, 10, 28)), image: Sample.photoImage(seed: 3))
        try await store.save(bodyPhoto(.back, takenAt: noonUTC(2026, 10, 28)), image: Sample.photoImage(seed: 4))
        let output = temporaryDirectory()
        let archive = try await store.exportArchive(to: output)
        defer { try? FileManager.default.removeItem(at: output) }
        #expect(archive.deletingLastPathComponent().standardizedFileURL == output.standardizedFileURL)
        #expect(archive.lastPathComponent.hasPrefix("Pulse-photos-de-corps-") && archive.pathExtension == "zip")
        let names = try unzippedFileNames(archive)
        #expect(names.contains("2026-08-01-face.jpg") && names.contains("2026-10-28-dos.jpg"))
        #expect(names.contains("2026-10-28-profil.jpg") && names.contains("2026-10-28-dos-2.jpg"))
        #expect(names.count == 4)
    }

    @Test func exportArchiveLeavesNoStagingFolder() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory)
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 1))
        let output = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: output) }
        _ = try await store.exportArchive(to: output)
        #expect(files(in: output).count == 1)
        #expect(!files(in: directory).contains { $0.hasPrefix(".export-") })
        #expect(try await store.photos().count == 1)   // le balayage ne touche pas aux dossiers de travail
    }

    @Test func exportArchiveReplacesAnEarlierArchive() async throws {
        let store = FileBodyPhotoStore(directory: temporaryDirectory())
        try await store.save(bodyPhoto(), image: Sample.photoImage(seed: 1))
        let output = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: output) }
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        // Une archive d'un autre jour, et un fichier sans rapport.
        try Data([1]).write(to: output.appendingPathComponent("Pulse-photos-de-corps-2026-01-01.zip"))
        try Data([2]).write(to: output.appendingPathComponent("Pulse-2026-01-01.json"))
        let archive = try await store.exportArchive(to: output)
        #expect(files(in: output).sorted() == ["Pulse-2026-01-01.json", archive.lastPathComponent].sorted())
        let second = try await store.exportArchive(to: output)
        #expect(second == archive && files(in: output).count == 2)
    }

    /// Dézippe avec `ditto` et rend les noms des fichiers de l'archive.
    private func unzippedFileNames(_ archive: URL) throws -> [String] {
        let target = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: target) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, target.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        let enumerator = FileManager.default.enumerator(at: target, includingPropertiesForKeys: [.isRegularFileKey])
        return (enumerator?.allObjects as? [URL] ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.lastPathComponent)
    }
}

/// Test de frontière (spec §8) : rien d'une photo de corps ne passe dans l'export général.
@Test func generalExportHasNoBodyPhoto() async throws {
    let store = FileBodyPhotoStore(directory: temporaryDirectory())
    let photo = bodyPhoto(.front)
    let image = PhotoImage(image: Data(repeating: 0xC8, count: 4_096) + Data([0xFF, 0xD9]), thumbnail: Data(repeating: 0xC9, count: 256))
    try await store.save(photo, image: image)

    let box = try ModelContainerBox()
    try await SampleDataSeeder(container: box.container, calendar: Fixed.calendar).seed(now: Fixed.t0)
    try await SwiftDataSessionPhotoRepository(modelContainer: box.container)
        .add(Sample.sessionPhoto(sessionID: UUID(), order: 0), image: Sample.photoImage(seed: 1))
    // Un dossier par export : chaque export vide le sien avant d'écrire.
    let jsonOutput = temporaryDirectory()
    let csvOutput = temporaryDirectory()
    defer {
        try? FileManager.default.removeItem(at: jsonOutput)
        try? FileManager.default.removeItem(at: csvOutput)
    }
    func exporter(_ directory: URL) -> SwiftDataExporter {
        SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                          exerciseNames: { _ in nil }, directory: directory, timeZone: Fixed.calendar.timeZone)
    }
    _ = try await exporter(jsonOutput).exportJSON()
    _ = try await exporter(csvOutput).exportCSVArchive()

    let forbidden = [photo.id.uuidString, photo.id.uuidString.lowercased(), "-thumb.jpg", "index.json", "Pulse-photos-de-corps"]
    var scanned = 0
    for output in [jsonOutput, csvOutput] {
        let enumerator = try #require(FileManager.default.enumerator(at: output, includingPropertiesForKeys: [.isRegularFileKey]))
        let exported = (enumerator.allObjects as? [URL] ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        for url in exported {
            scanned += 1
            let name = url.path.replacingOccurrences(of: output.path, with: "")
            #expect(!forbidden.contains { name.contains($0) }, "nom de fichier : \(name)")
            let data = try Data(contentsOf: url)
            #expect(data.range(of: image.image) == nil && data.range(of: image.thumbnail) == nil, "octets de l'image : \(name)")
            let text = String(bytes: data, encoding: .utf8) ?? ""
            #expect(!forbidden.contains { text.contains($0) }, "contenu : \(name)")
        }
    }
    #expect(scanned >= 4, "le test doit avoir lu des fichiers : JSON, CSV, photos de séance et archive")
}
