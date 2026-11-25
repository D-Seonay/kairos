import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import Testing

/// Les réglages, l'ajout et la suppression des photos de corps.
@MainActor
struct BodyPhotosModelActionsTests: BodyPhotosModelTesting {
    let service = Self.makeService()

    // MARK: Réglages

    @Test func disablingTheLockNeedsAuthentication() async {
        let authentication = StubOwnerAuthentication()
        let lock = InMemoryBodyPhotoLockStore()
        let model = makeModel(authentication, lock: lock)
        await model.appear()
        authentication.succeeds = false
        await model.setLockEnabled(false)
        #expect(model.isLockEnabled)
        #expect(lock.isLockEnabled)
        authentication.succeeds = true
        await model.setLockEnabled(false)
        #expect(!model.isLockEnabled)
        #expect(!lock.isLockEnabled)
        #expect(authentication.reasons == Array(repeating: BodyPhotosTestText.unlockReason, count: 3))
        // Réactiver le verrou ne demande rien.
        await model.setLockEnabled(true)
        #expect(model.isLockEnabled)
        #expect(lock.isLockEnabled)
        #expect(authentication.reasons.count == 3)
    }

    @Test func exportNeedsAuthentication() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = await unlockedModel(authentication)
        authentication.succeeds = false
        #expect(await model.exportArchive() == nil)
        #expect(authentication.reasons.count == 2)
        authentication.succeeds = true
        #expect(await model.exportArchive() != nil)
        #expect(authentication.reasons.count == 3)
        await model.exportFinished(failed: false)
        #expect(model.errorMessage == nil)
    }

    @Test func exportWithTheLockOffAsksNothing() async throws {
        try await seed(.front, "2026-11-01T08:00")
        let authentication = StubOwnerAuthentication()
        let model = makeModel(authentication, lock: InMemoryBodyPhotoLockStore(isLockEnabled: false))
        await model.appear()
        #expect(await model.exportArchive() != nil)
        #expect(authentication.reasons.isEmpty)
        await model.exportFinished(failed: true)
        #expect(model.errorMessage == "L'export n'a pas pu être enregistré.")
    }

    @Test func relockWhileTheArchiveIsWrittenDiscardsIt() async throws {
        let store = GatedExportBodyPhotoStore()
        let service = BodyPhotoService(store: store, measurements: InMemoryBodyMeasurementRepository(),
                                       calendar: PhotosTestClock.calendar, timeZone: PhotosTestClock.calendar.timeZone,
                                       exportDirectory: Self.uniqueExportDirectory(),
                                       now: { PhotosTestClock.date("2026-11-20T12:00") })
        _ = try await service.save(service.process(TestImages.jpeg()), pose: .front,
                                   takenAt: PhotosTestClock.date("2026-11-01T08:00"))
        let model = BodyPhotosModel(service: service, authentication: StubOwnerAuthentication(), lock: InMemoryBodyPhotoLockStore(),
                                    calendar: PhotosTestClock.calendar, now: { PhotosTestClock.date("2026-11-20T12:00") })
        await model.appear()
        let export = Task { await model.exportArchive() }
        while await !store.isExporting { await Task.yield() }
        model.scenePhaseChanged(.background)
        await store.open()
        #expect(await export.value == nil)
        let archive = try #require(await store.archive)
        #expect(!FileManager.default.fileExists(atPath: archive.path))
        #expect(model.lockState == .locked)
    }

    @Test func deleteAllEmptiesTheList() async throws {
        try await seed(.front, "2026-11-01T08:00")
        try await seed(.back, "2026-10-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        await model.deleteAll()
        #expect(model.days.isEmpty)
        #expect(model.thumbnails.isEmpty)
        #expect(try await service.photos().isEmpty)
        #expect(model.announcement == "Photos de corps supprimées")
    }

    // MARK: Ajout et suppression

    @Test func draftWithoutCaptureDateTakesToday() async throws {
        let model = await unlockedModel(StubOwnerAuthentication())
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(draft.takenAt == PhotosTestClock.date("2026-11-20T12:00"))
    }

    @Test func unreadableImageGivesNoDraft() async {
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(await model.prepare(Data([1, 2, 3])) == nil)
        #expect(model.errorMessage == "Une image n'a pas pu être lue.")
        #expect(await model.prepare(nil) == nil)
    }

    @Test func saveAddsAnnouncesAndReloads() async throws {
        let model = await unlockedModel(StubOwnerAuthentication())
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(await model.save(draft, pose: .side, takenAt: PhotosTestClock.date("2026-11-02T09:00")))
        #expect(model.announcement == "Photo ajoutée")
        let photo = try #require(model.days.first?.photos[.side])
        #expect(photo.takenAt == PhotosTestClock.date("2026-11-02T09:00"))
        #expect(model.thumbnails[photo.id] != nil)
    }

    @Test func futureDateIsBroughtBackToNow() async throws {
        let model = await unlockedModel(StubOwnerAuthentication())
        let draft = try #require(await model.prepare(TestImages.jpeg()))
        #expect(await model.save(draft, pose: .front, takenAt: PhotosTestClock.date("2026-12-25T09:00")))
        #expect(model.days.first?.photos[.front]?.takenAt == PhotosTestClock.date("2026-11-20T12:00"))
    }

    @Test func replacedPhotoIsTheSamePoseOnTheSameDay() async throws {
        let existing = try await seed(.front, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(await model.photoToReplace(pose: .front, on: PhotosTestClock.date("2026-11-01T21:00"))?.id == existing.id)
        #expect(await model.photoToReplace(pose: .side, on: PhotosTestClock.date("2026-11-01T21:00")) == nil)
        #expect(await model.photoToReplace(pose: .front, on: PhotosTestClock.date("2026-11-02T08:00")) == nil)
    }

    @Test func deleteRemovesAndAnnounces() async throws {
        let removed = try await seed(.front, "2026-11-01T08:00")
        let kept = try await seed(.back, "2026-11-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(await model.delete(removed.id))
        #expect(model.announcement == "Photo supprimée")
        #expect(model.photos.map(\.id) == [kept.id])
        #expect(model.thumbnails[removed.id] == nil)
    }

    @Test func comparisonNeedsTwoDatesOfOnePose() async throws {
        try await seed(.front, "2026-08-01T08:00")
        try await seed(.side, "2026-10-28T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(!model.canCompare)
        try await seed(.front, "2026-10-28T08:00")
        await model.appear()
        #expect(model.canCompare)
        #expect(model.makeCompareModel().poses == [.front])
    }

    @Test func slotLabelsNamePoseAndDay() async throws {
        let photo = try await seed(.side, "2026-08-01T08:00")
        let model = await unlockedModel(StubOwnerAuthentication())
        #expect(model.spokenLabel(of: photo) == "Photo de profil, 1er août 2026")
        let day = try #require(model.days.first)
        #expect(model.dayTitle(day) == "1er août")
        #expect(model.photoCountText(day) == "1 photo")
    }
}
