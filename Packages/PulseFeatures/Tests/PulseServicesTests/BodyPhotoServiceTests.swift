import Foundation
import PulseDomain
import PulseServices
import Testing

struct BodyPhotoServiceTests {
    private let store = InMemoryBodyPhotoStore()
    private let measurements = InMemoryBodyMeasurementRepository()

    private func makeService() -> BodyPhotoService {
        BodyPhotoService(store: store, measurements: measurements, calendar: TestClock.calendar, timeZone: .gmt,
                         now: { TestClock.date("2026-11-20T12:00") })
    }

    private func processed() throws -> ProcessedPhoto {
        try PhotoProcessor.process(TestImages.jpeg(), timeZone: .gmt)
    }

    private func weighing(_ date: String, _ kg: Double) -> BodyMeasurement {
        let day = TestClock.date(date)
        return BodyMeasurement(date: day, weightKg: kg, source: .manual, createdAt: day, updatedAt: day)
    }

    @Test func saveReplacesSamePoseSameDay() async throws {
        let service = makeService()
        let first = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        let second = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T20:00"))
        let stored = try await service.photos()
        #expect(stored.map(\.id) == [second.id])
        #expect(try await service.image(of: first.id) == nil)
        #expect(try await service.thumbnail(of: second.id) != nil)
    }

    @Test func saveKeepsOtherPosesAndDays() async throws {
        let service = makeService()
        let front = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        let side = try await service.save(processed(), pose: .side, takenAt: TestClock.date("2026-11-01T08:00"))
        let nextDay = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-02T08:00"))
        #expect(Set(try await service.photos().map(\.id)) == [front.id, side.id, nextDay.id])
        let days = try await service.days()
        #expect(days.count == 2)
        #expect(days[0].photos[.front]?.id == nextDay.id)
        #expect(days[1].photos[.front]?.id == front.id && days[1].photos[.side]?.id == side.id)
    }

    @Test func savedPhotoCarriesTheChosenDateAndTheClock() async throws {
        let service = makeService()
        let taken = TestClock.date("2026-10-28T09:00")
        let saved = try await service.save(processed(), pose: .back, takenAt: taken)
        #expect(saved.pose == .back && saved.takenAt == taken && saved.createdAt == TestClock.date("2026-11-20T12:00"))
    }

    @Test func concurrentSavesOfTheSamePoseAndDayLeaveOnePhoto() async throws {
        let service = makeService()
        let photo = try processed()
        let day = TestClock.date("2026-11-01T08:00")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 { group.addTask { _ = try await service.save(photo, pose: .front, takenAt: day) } }
            try await group.waitForAll()
        }
        #expect(try await service.photos().count == 1)
    }

    /// Les photos de corps n'ont aucune autre copie : un remplacement dont l'écriture échoue garde l'ancienne photo.
    @Test func aFailedReplaceKeepsTheOldPhoto() async throws {
        let failing = FailingBodyPhotoStore()
        let service = BodyPhotoService(store: failing, measurements: measurements, calendar: TestClock.calendar, timeZone: .gmt,
                                       now: { TestClock.date("2026-11-20T12:00") })
        let old = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        await failing.setFailsSave(true)
        await #expect(throws: FailingBodyPhotoStore.Failure.self) {
            _ = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T20:00"))
        }
        #expect(try await service.photos().map(\.id) == [old.id])
        #expect(try await service.image(of: old.id) != nil)
    }

    /// La nouvelle photo est écrite : un échec de suppression de l'ancienne ne fait pas échouer l'ajout, et le remplacement
    /// suivant la retire.
    @Test func aFailedDeleteOfTheOldPhotoStillSavesTheNewOne() async throws {
        let failing = FailingBodyPhotoStore()
        let service = BodyPhotoService(store: failing, measurements: measurements, calendar: TestClock.calendar, timeZone: .gmt,
                                       now: { TestClock.date("2026-11-20T12:00") })
        let old = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        await failing.setFailsDelete(true)
        let new = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T20:00"))
        #expect(Set(try await service.photos().map(\.id)) == [old.id, new.id])
        await failing.setFailsDelete(false)
        let third = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T21:00"))
        #expect(try await service.photos().map(\.id) == [third.id])
    }

    @Test func existingFindsSamePoseSameDay() async throws {
        let service = makeService()
        let saved = try await service.save(processed(), pose: .side, takenAt: TestClock.date("2026-11-01T08:00"))
        #expect(try await service.existing(pose: .side, on: TestClock.date("2026-11-01T22:00"))?.id == saved.id)
        #expect(try await service.existing(pose: .front, on: TestClock.date("2026-11-01T08:00")) == nil)
        #expect(try await service.existing(pose: .side, on: TestClock.date("2026-11-02T08:00")) == nil)
    }

    @Test func processReadsAnImage() async throws {
        let service = makeService()
        let result = try await service.process(TestImages.jpeg())
        #expect(!result.image.image.isEmpty && !result.image.thumbnail.isEmpty)
        await #expect(throws: PhotoProcessingError.unreadable) { try await service.process(Data([1, 2, 3])) }
    }

    @Test func weightChangeReadsMeasurements() async throws {
        for weighing in [weighing("2026-08-01T07:00", 70), weighing("2026-10-28T07:00", 68.6)] {
            try await measurements.save(weighing)
        }
        let change = try await makeService().weightChange(from: TestClock.date("2026-08-04T10:00"),
                                                          to: TestClock.date("2026-10-30T10:00"))
        #expect(try abs(#require(change) - -1.4) < 0.01)
    }

    @Test func weightChangeIsNilWithoutATrendOnBothDates() async throws {
        try await measurements.save(weighing("2026-08-01T07:00", 70))
        let change = try await makeService().weightChange(from: TestClock.date("2026-08-04T10:00"),
                                                          to: TestClock.date("2026-10-30T10:00"))
        #expect(change == nil)
    }

    @Test func weightChangeReadsEnoughWeighingsForTheTrendBeforeTheFirstDate() async throws {
        // La tendance du 14 août (point le plus récent dans les 7 jours avant le 20) moyenne le 8 (71) et le 14 (70) : 70,5.
        for weighing in [weighing("2026-08-08T07:00", 71), weighing("2026-08-14T07:00", 70), weighing("2026-10-28T07:00", 68.5)] {
            try await measurements.save(weighing)
        }
        let change = try await makeService().weightChange(from: TestClock.date("2026-08-20T10:00"),
                                                          to: TestClock.date("2026-10-30T10:00"))
        #expect(try abs(#require(change) - -2.0) < 0.01)
    }

    @Test func weightChangeCountsAWeighingOfTheLastDay() async throws {
        try await measurements.save(weighing("2026-08-01T07:00", 70))
        try await measurements.save(weighing("2026-10-30T23:30", 68.5))
        let change = try await makeService().weightChange(from: TestClock.date("2026-08-04T10:00"),
                                                          to: TestClock.date("2026-10-30T10:00"))
        #expect(try abs(#require(change) - -1.5) < 0.01)
    }

    @Test func deleteRemovesOnePhoto() async throws {
        let service = makeService()
        let kept = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        let removed = try await service.save(processed(), pose: .back, takenAt: TestClock.date("2026-11-01T08:00"))
        try await service.delete(photoID: removed.id)
        #expect(try await service.photos().map(\.id) == [kept.id])
    }

    @Test func deleteAllEmptiesTheStore() async throws {
        let service = makeService()
        _ = try await service.save(processed(), pose: .front, takenAt: TestClock.date("2026-11-01T08:00"))
        _ = try await service.save(processed(), pose: .back, takenAt: TestClock.date("2026-11-02T08:00"))
        try await service.deleteAll()
        #expect(try await service.photos().isEmpty)
        #expect(try await service.days().isEmpty)
    }

    @Test func exportWritesIntoTheExportFolderAndDiscardRemovesIt() async throws {
        let service = makeService()
        let url = try await service.exportArchive()
        #expect(url.deletingLastPathComponent().standardizedFileURL == BodyPhotoService.exportDirectory.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: url.path))
        await service.discardExport()
        #expect(!FileManager.default.fileExists(atPath: BodyPhotoService.exportDirectory.path))
        await service.discardExport()
    }

    @Test func lockIsEnabledByDefault() {
        let suite = "pulse.tests.bodyPhotoLock.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let lock = UserDefaultsBodyPhotoLockStore(suiteName: suite)
        #expect(lock.isLockEnabled)
        lock.setLockEnabled(false)
        #expect(!lock.isLockEnabled)
        #expect(!UserDefaultsBodyPhotoLockStore(suiteName: suite).isLockEnabled)
        lock.setLockEnabled(true)
        #expect(lock.isLockEnabled)
    }

    @Test func inMemoryLockStartsEnabledAndFollowsTheSetting() {
        let lock = InMemoryBodyPhotoLockStore()
        #expect(lock.isLockEnabled)
        lock.setLockEnabled(false)
        #expect(!lock.isLockEnabled)
        #expect(!InMemoryBodyPhotoLockStore(isLockEnabled: false).isLockEnabled)
    }
}

/// Des photos de corps en mémoire dont l'écriture ou la suppression échoue sur demande (disque plein, protection des fichiers).
private actor FailingBodyPhotoStore: BodyPhotoStore {
    struct Failure: Error {}

    private let inner = InMemoryBodyPhotoStore()
    private var failsSave = false
    private var failsDelete = false

    func setFailsSave(_ fails: Bool) { failsSave = fails }
    func setFailsDelete(_ fails: Bool) { failsDelete = fails }

    func photos() async throws -> [BodyPhoto] { try await inner.photos() }
    func image(of photoID: UUID) async throws -> PhotoImage? { try await inner.image(of: photoID) }

    func save(_ photo: BodyPhoto, image: PhotoImage) async throws {
        if failsSave { throw Failure() }
        try await inner.save(photo, image: image)
    }

    func delete(photoID: UUID) async throws {
        if failsDelete { throw Failure() }
        try await inner.delete(photoID: photoID)
    }

    func deleteAll() async throws { try await inner.deleteAll() }
    func exportArchive(to directory: URL) async throws -> URL { try await inner.exportArchive(to: directory) }
}
