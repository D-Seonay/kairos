import Foundation
import PulseDomain
import PulseServices

/// Des photos de corps en mémoire dont l'export attend un feu vert : le test peut reverrouiller pendant l'écriture de l'archive.
/// L'archive porte un nom unique, qu'aucun autre test ne recrée.
actor GatedExportBodyPhotoStore: BodyPhotoStore {
    private let inner = InMemoryBodyPhotoStore()
    private var release: CheckedContinuation<Void, Never>?
    /// Vrai dès que l'export attend son feu vert.
    private(set) var isExporting = false
    /// L'archive écrite, une fois le feu vert donné.
    private(set) var archive: URL?

    func photos() async throws -> [BodyPhoto] {
        try await inner.photos()
    }

    func image(of photoID: UUID) async throws -> PhotoImage? {
        try await inner.image(of: photoID)
    }

    func save(_ photo: BodyPhoto, image: PhotoImage) async throws {
        try await inner.save(photo, image: image)
    }

    func delete(photoID: UUID) async throws {
        try await inner.delete(photoID: photoID)
    }

    func deleteAll() async throws {
        try await inner.deleteAll()
    }

    func exportArchive(to directory: URL) async throws -> URL {
        isExporting = true
        await withCheckedContinuation { release = $0 }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("gated-\(UUID().uuidString).zip")
        try Data([1]).write(to: url)
        archive = url
        return url
    }

    /// Laisse l'export écrire son archive.
    func open() {
        release?.resume()
        release = nil
    }
}
