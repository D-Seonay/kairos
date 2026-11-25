import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

/// Midi UTC du jour donné : le même jour local dans tous les fuseaux.
private func noonUTC(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Fixed.t0
}

private func bodyPhoto(_ pose: BodyPose, takenAt: Date = noonUTC(2026, 8, 1)) -> BodyPhoto {
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

/// Un index abîmé (octets lus, JSON invalide) se reconstruit ; un index verrouillé (octets illisibles) attend, voir
/// `FileBodyPhotoStoreTests.unreadableIndexRefusesWritesAndKeepsEveryPhoto`.
@Suite struct FileBodyPhotoStoreRepairTests {
    /// Un index abîmé (octets lus, JSON invalide) est reconstruit à partir des images : aucune n'est perdue ni supprimée, et
    /// l'ajout comme la suppression remarchent.
    @Test func damagedIndexIsRebuiltFromTheImages() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, now: { Fixed.t0 })
        let first = bodyPhoto(.front)
        let second = bodyPhoto(.back)
        try await store.save(first, image: Sample.photoImage(seed: 1))
        try await store.save(second, image: Sample.photoImage(seed: 2))
        try "x".write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)

        let rebuilt = try await store.photos()
        #expect(Set(rebuilt.map(\.id)) == [first.id, second.id])
        #expect(rebuilt.allSatisfy { $0.takenAt == Fixed.t0 && $0.createdAt == Fixed.t0 })
        // Deux photos sans métadonnées ne partagent pas la même pose : les deux restent visibles dans la liste par jour.
        #expect(Set(rebuilt.map(\.pose)).count == 2)
        #expect(try await store.image(of: first.id) == Sample.photoImage(seed: 1))
        #expect(try await store.image(of: second.id) == Sample.photoImage(seed: 2))
        #expect(try Set(indexEntries(in: directory).map(\.id)) == [first.id, second.id])
        // La copie de l'index abîmé est gardée telle quelle, et le balayage ne la touche pas.
        let backup = directory.appendingPathComponent(FileBodyPhotoStore.damagedIndexName)
        #expect(try String(contentsOf: backup, encoding: .utf8) == "x")

        try await store.delete(photoID: first.id)
        let added = bodyPhoto(.side)
        try await store.save(added, image: Sample.photoImage(seed: 3))
        #expect(Set(try await store.photos().map(\.id)) == [second.id, added.id])
        #expect(files(in: directory).contains(FileBodyPhotoStore.damagedIndexName))
    }

    /// Les entrées encore lisibles d'un index abîmé reviennent telles quelles ; seule l'image sans entrée lisible est devinée.
    @Test func damagedIndexKeepsItsReadableEntries() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, now: { Fixed.t0 })
        let intact = bodyPhoto(.side, takenAt: noonUTC(2026, 8, 1))
        let lost = bodyPhoto(.back, takenAt: noonUTC(2026, 9, 1))
        try await store.save(intact, image: Sample.photoImage(seed: 1))
        try await store.save(lost, image: Sample.photoImage(seed: 2))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let intactJSON = try #require(String(data: try encoder.encode(intact), encoding: .utf8))
        let damaged = "[\(intactJSON), {\"id\": \"\(lost.id.uuidString)\", \"pose\": \"upside-down\"}]"
        try damaged.write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
        // Une vignette disparue est remplacée par une copie de l'image : la photo reste affichable.
        try FileManager.default.removeItem(at: directory.appendingPathComponent("\(lost.id.uuidString)-thumb.jpg"))

        let rebuilt = try await store.photos()
        #expect(rebuilt.count == 2)
        #expect(rebuilt.contains(intact))
        let guessed = try #require(rebuilt.first { $0.id == lost.id })
        #expect(guessed.takenAt == Fixed.t0)
        #expect(try await store.image(of: lost.id)?.thumbnail == Sample.photoImage(seed: 2).image)
    }

    @Test func emptyIndexFileIsRebuilt() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, now: { Fixed.t0 })
        let photo = bodyPhoto(.front)
        try await store.save(photo, image: Sample.photoImage(seed: 1))
        try Data().write(to: directory.appendingPathComponent("index.json"))
        #expect(try await store.photos().map(\.id) == [photo.id])
    }
}
