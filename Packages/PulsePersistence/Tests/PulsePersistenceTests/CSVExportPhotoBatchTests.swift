import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

/// Les images de séance sont lues par lots, chacun dans son contexte (issue #57) : l'archive ne dépend pas de la taille des lots.
struct CSVExportPhotoBatchTests {
    /// Sept photos vivantes sur deux séances, dont deux de même rang le même jour, et une photo supprimée.
    private func seededBox() async throws -> ModelContainerBox {
        let box = try ModelContainerBox()
        let repo = SwiftDataSessionPhotoRepository(modelContainer: box.container)
        let first = try await Sample.savedSession(in: box, id: try #require(UUID(uuidString: "ABCDEF12-0000-0000-0000-000000000001")))
        let second = try await Sample.savedSession(in: box, id: try #require(UUID(uuidString: "12ABCDEF-0000-0000-0000-000000000002")))
        var seed: UInt8 = 1
        for order in 0..<4 {
            try await repo.add(Sample.sessionPhoto(sessionID: first, order: order, createdAt: Fixed.t0),
                               image: Sample.photoImage(seed: seed))
            seed += 1
        }
        for order in [0, 1, 1] {
            try await repo.add(Sample.sessionPhoto(sessionID: second, order: order, createdAt: Fixed.t1),
                               image: Sample.photoImage(seed: seed))
            seed += 1
        }
        let removed = Sample.sessionPhoto(sessionID: first, order: 4)
        try await repo.add(removed, image: Sample.photoImage(seed: 99))
        try await repo.delete(photoID: removed.id)
        return box
    }

    /// Chaque fichier de l'archive (chemin relatif -> octets), README compris.
    private func exportedFiles(_ box: ModelContainerBox, batchSize: Int) async throws -> [String: Data] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var exporter = SwiftDataExporter(container: box.container, appVersion: "1.0 (1)", contentVersion: "1.0.0",
                                         exerciseNames: { _ in nil }, directory: directory, timeZone: Fixed.calendar.timeZone)
        exporter.photoBatchSize = batchSize
        // L'heure d'export est écrite dans le README : figée, deux exports à des secondes différentes restent identiques.
        exporter.now = { Fixed.t0 }
        _ = try await exporter.exportCSVArchive()
        let folder = try #require(exporter.lastCSVDirectory(in: directory))
        let enumerator = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
        var files: [String: Data] = [:]
        let urls = enumerator.allObjects as? [URL] ?? []
        for url in urls where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            files[url.path.replacingOccurrences(of: folder.path + "/", with: "")] = try Data(contentsOf: url)
        }
        return files
    }

    @Test func archiveIsTheSameWhateverTheBatchSize() async throws {
        let box = try await seededBox()
        let reference = try await exportedFiles(box, batchSize: 1_000)
        #expect(reference.keys.filter { $0.hasPrefix("photos/") }.count == 7)
        for size in [1, 2, 3, 8] {
            let files = try await exportedFiles(box, batchSize: size)
            #expect(Set(files.keys) == Set(reference.keys), "lots de \(size)")
            for (path, data) in reference {
                #expect(files[path] == data, "lots de \(size) : \(path)")
            }
        }
    }

    @Test func everyImageIsCopiedAcrossBatches() async throws {
        let box = try await seededBox()
        let files = try await exportedFiles(box, batchSize: 3)
        let images = files.filter { $0.key.hasPrefix("photos/") }.values
        let expected = (1...7).map { Sample.photoImage(seed: UInt8($0)).image }
        #expect(Set(images) == Set(expected))
        #expect(!images.contains(Sample.photoImage(seed: 99).image))
    }
}
