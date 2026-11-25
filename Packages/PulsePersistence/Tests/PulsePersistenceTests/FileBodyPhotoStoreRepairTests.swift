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
/// Donne à l'image de la photo la date de création voulue : la reconstruction la relit.
private func setFileDate(_ date: Date, of id: UUID, in directory: URL) throws {
    try FileManager.default.setAttributes([.creationDate: date, .modificationDate: date],
                                          ofItemAtPath: directory.appendingPathComponent("\(id.uuidString).jpg").path)
}

private func damageIndex(in directory: URL) throws {
    try "x".write(to: directory.appendingPathComponent("index.json"), atomically: true, encoding: .utf8)
}

/// Midi UTC du jour donné plus `minutes` minutes.
private func utc(_ month: Int, _ day: Int, minutes: Int = 0) -> Date {
    noonUTC(2026, month, day).addingTimeInterval(TimeInterval(minutes * 60))
}

@Suite struct FileBodyPhotoStoreRepairTests {
    /// Un index abîmé (octets lus, JSON invalide) est reconstruit à partir des images, chacune à la date de son fichier : aucune
    /// n'est perdue ni supprimée, et l'ajout comme la suppression remarchent.
    @Test func damagedIndexIsRebuiltFromTheImages() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, calendar: Fixed.calendar, now: { Fixed.t0 })
        let first = bodyPhoto(.front)
        let second = bodyPhoto(.back)
        try await store.save(first, image: Sample.photoImage(seed: 1))
        try await store.save(second, image: Sample.photoImage(seed: 2))
        try setFileDate(utc(8, 1), of: first.id, in: directory)
        try setFileDate(utc(9, 1), of: second.id, in: directory)
        try damageIndex(in: directory)

        let rebuilt = try await store.photos()
        #expect(Set(rebuilt.map(\.id)) == [first.id, second.id])
        #expect(rebuilt.first { $0.id == first.id }?.takenAt == utc(8, 1))
        #expect(rebuilt.first { $0.id == second.id }?.takenAt == utc(9, 1))
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

    /// Douze images retrouvées, trois par jour : aucune ne partage sa pose et son jour avec une autre, donc toutes sont visibles.
    /// Remplacer ensuite la photo de face d'un de ces jours (seule la photo confirmée part) laisse les onze autres en place.
    @Test func twelveRecoveredImagesSurviveAReplaceOnTheirDay() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, calendar: Fixed.calendar, now: { Fixed.t0 })
        var ids: [UUID] = []
        for day in 1...4 {
            for shot in 0..<3 {
                let photo = bodyPhoto(.front)
                try await store.save(photo, image: Sample.photoImage(seed: UInt8(ids.count + 1)))
                try setFileDate(utc(8, day, minutes: shot), of: photo.id, in: directory)
                ids.append(photo.id)
            }
        }
        try damageIndex(in: directory)

        let rebuilt = try await store.photos()
        #expect(Set(rebuilt.map(\.id)) == Set(ids))
        let slots = rebuilt.map { "\($0.pose)-\(Fixed.calendar.startOfDay(for: $0.takenAt))" }
        #expect(Set(slots).count == 12)
        // L'ordre habituel d'une prise : face, profil, dos.
        #expect(rebuilt.first { $0.id == ids[0] }?.pose == .front)
        #expect(rebuilt.first { $0.id == ids[1] }?.pose == .side)
        #expect(rebuilt.first { $0.id == ids[2] }?.pose == .back)

        // Ce que fait `BodyPhotoService.save(…, replacing:)` : la nouvelle photo, puis la suppression de la seule photo confirmée.
        let shown = try #require(rebuilt.first { $0.pose == .front && Fixed.calendar.isDate($0.takenAt, inSameDayAs: utc(8, 1)) })
        let new = bodyPhoto(.front, takenAt: utc(8, 1, minutes: 30))
        try await store.save(new, image: Sample.photoImage(seed: 50))
        try await store.delete(photoID: shown.id)
        let remaining = Set(try await store.photos().map(\.id))
        #expect(remaining == Set(ids.filter { $0 != shown.id } + [new.id]))
    }

    /// Sans date de fichier lisible, chaque image reçoit un jour à elle, en reculant depuis la veille de la reconstruction.
    @Test func undatedImagesGetOneDayEach() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, calendar: Fixed.calendar, now: { Fixed.t0 }, fileDate: { _ in nil })
        var ids: [UUID] = []
        for seed in 1...5 {
            let photo = bodyPhoto(.front)
            try await store.save(photo, image: Sample.photoImage(seed: UInt8(seed)))
            ids.append(photo.id)
        }
        try damageIndex(in: directory)

        let rebuilt = try await store.photos()
        #expect(Set(rebuilt.map(\.id)) == Set(ids))
        let days = Set(rebuilt.map { Fixed.calendar.startOfDay(for: $0.takenAt) })
        #expect(days.count == 5)
        let today = Fixed.calendar.startOfDay(for: Fixed.t0)
        let yesterday = try #require(Fixed.calendar.date(byAdding: .day, value: -1, to: today))
        #expect(days.allSatisfy { $0 < today })
        #expect(days.contains(yesterday))
    }

    /// Les entrées encore lisibles d'un index abîmé reviennent telles quelles ; seule l'image sans entrée lisible est devinée.
    @Test func damagedIndexKeepsItsReadableEntries() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, calendar: Fixed.calendar, now: { Fixed.t0 })
        let intact = bodyPhoto(.side, takenAt: noonUTC(2026, 8, 1))
        let lost = bodyPhoto(.back, takenAt: noonUTC(2026, 9, 1))
        try await store.save(intact, image: Sample.photoImage(seed: 1))
        try await store.save(lost, image: Sample.photoImage(seed: 2))
        try setFileDate(utc(9, 1), of: lost.id, in: directory)
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
        #expect(guessed.takenAt == utc(9, 1))
        #expect(try await store.image(of: lost.id)?.thumbnail == Sample.photoImage(seed: 2).image)
    }

    @Test func emptyIndexFileIsRebuilt() async throws {
        let directory = temporaryDirectory()
        let store = FileBodyPhotoStore(directory: directory, calendar: Fixed.calendar, now: { Fixed.t0 })
        let photo = bodyPhoto(.front)
        try await store.save(photo, image: Sample.photoImage(seed: 1))
        try Data().write(to: directory.appendingPathComponent("index.json"))
        #expect(try await store.photos().map(\.id) == [photo.id])
    }
}

/// Les règles de datation et de pose des images retrouvées.
@Suite struct BodyPhotoIndexRepairTests {
    private let calendar = Fixed.calendar

    /// Un jour qui a déjà ses trois poses : en dernier recours, la quatrième image reprend face, profil, dos tour à tour.
    @Test func aFourthImageOnAFullDayFallsBackToAlternatingPoses() {
        let images = (0..<4).map { BodyPhotoIndexRepair.Image(id: UUID(), fileDate: utc(8, 1, minutes: $0)) }
        let entries = BodyPhotoIndexRepair.entries(for: images, existing: [], now: Fixed.t0, calendar: calendar)
        #expect(entries.map(\.pose) == [.front, .side, .back, .front])
    }

    /// Une pose déjà prise ce jour-là par une entrée relue n'est pas redonnée.
    @Test func posesTakenByReadableEntriesAreSkipped() {
        let kept = BodyPhoto(id: UUID(), pose: .front, takenAt: utc(8, 1), createdAt: utc(8, 1))
        let image = BodyPhotoIndexRepair.Image(id: UUID(), fileDate: utc(8, 1, minutes: 5))
        let entries = BodyPhotoIndexRepair.entries(for: [image], existing: [kept], now: Fixed.t0, calendar: calendar)
        #expect(entries.map(\.pose) == [.side])
    }

    /// Une image sans date saute les jours qui ont déjà une photo.
    @Test func undatedImagesSkipDaysThatHavePhotos() throws {
        let today = calendar.startOfDay(for: Fixed.t0)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let kept = BodyPhoto(id: UUID(), pose: .back, takenAt: yesterday.addingTimeInterval(3_600), createdAt: yesterday)
        let image = BodyPhotoIndexRepair.Image(id: UUID(), fileDate: nil)
        let entries = BodyPhotoIndexRepair.entries(for: [image], existing: [kept], now: Fixed.t0, calendar: calendar)
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        #expect(entries.count == 1 && calendar.isDate(entries[0].takenAt, inSameDayAs: twoDaysAgo))
    }
}
