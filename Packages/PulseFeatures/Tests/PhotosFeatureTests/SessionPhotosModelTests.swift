import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import PulseTestSupport
import Testing

@MainActor
struct SessionPhotosModelTests {
    private let sessionID = UUID()
    private let calendar = PhotosTestClock.calendar
    private let service = SessionPhotoService(repository: InMemorySessionPhotoRepository(), timeZone: .gmt,
                                              now: { PhotosTestClock.date("2026-08-01T18:42") })

    private func makeModel() -> SessionPhotosModel {
        SessionPhotosModel(service: service, sessionID: sessionID, calendar: calendar)
    }

    private func seed(_ count: Int) async throws {
        for _ in 0..<count { _ = try await service.add(TestImages.jpeg(), to: sessionID) }
    }

    @Test func loadShowsPhotosAndThumbnails() async throws {
        try await seed(3)
        let model = makeModel()
        await model.load()
        #expect(model.photos.count == 3)
        #expect(Set(model.thumbnails.keys) == Set(model.photos.map(\.id)))
        #expect(model.thumbnails.values.allSatisfy { !$0.isEmpty })
        #expect(model.remainingSlots == 3)
        #expect(model.canAdd)
        #expect(model.errorMessage == nil)
    }

    @Test func otherSessionsPhotosAreNotShown() async throws {
        _ = try await service.add(TestImages.jpeg(), to: UUID())
        let model = makeModel()
        await model.load()
        #expect(model.photos.isEmpty)
    }

    @Test func addAppendsAndAnnounces() async throws {
        let model = makeModel()
        await model.load()
        await model.add([TestImages.jpeg()])
        #expect(model.photos.count == 1)
        #expect(model.thumbnails[model.photos[0].id] != nil)
        #expect(model.announcement == "Photo ajoutée")
        #expect(model.errorMessage == nil)
        #expect(!model.isAdding)
    }

    @Test func addingSeveralAnnouncesTheCount() async throws {
        let model = makeModel()
        await model.add([TestImages.jpeg(), TestImages.jpeg(), TestImages.jpeg()])
        #expect(model.photos.map(\.order) == [0, 1, 2])
        #expect(model.announcement == "3 photos ajoutées")
    }

    @Test func multipleImportIsCappedToRemainingSlots() async throws {
        try await seed(4)
        let model = makeModel()
        await model.load()
        await model.add(Array(repeating: TestImages.jpeg(), count: 4))
        #expect(model.photos.count == 6)
        #expect(model.errorMessage == "6 photos au maximum par séance : 2 n'ont pas été ajoutées.")
        #expect(!model.canAdd)
    }

    @Test func addingAtSixAddsNothingAndSaysSo() async throws {
        try await seed(6)
        let model = makeModel()
        await model.load()
        await model.add([TestImages.jpeg()])
        #expect(model.photos.count == 6)
        #expect(model.errorMessage == "6 photos au maximum par séance : 1 n'a pas été ajoutée.")
        #expect(model.announcement == nil)
    }

    @Test func canAddIsFalseAtSix() async throws {
        let model = makeModel()
        await model.load()
        #expect(model.canAdd)
        try await seed(5)
        await model.load()
        #expect(model.canAdd && model.remainingSlots == 1)
        try await seed(1)
        await model.load()
        #expect(!model.canAdd && model.remainingSlots == 0)
    }

    @Test func unreadableImageReportsAnError() async throws {
        let model = makeModel()
        await model.add([Data("pas une image".utf8), TestImages.jpeg()])
        #expect(model.photos.count == 1)
        #expect(model.errorMessage == "Une image n'a pas pu être lue.")
        #expect(model.announcement == "Photo ajoutée")
    }

    @Test func addClearsThePreviousError() async throws {
        let model = makeModel()
        await model.add([Data("pas une image".utf8)])
        #expect(model.errorMessage != nil)
        await model.add([TestImages.jpeg()])
        #expect(model.errorMessage == nil)
    }

    @Test func deleteRemovesThePhotoAndAnnounces() async throws {
        let model = makeModel()
        await model.add([TestImages.jpeg(), TestImages.jpeg()])
        let removed = model.photos[0].id
        await model.delete(removed)
        #expect(model.photos.count == 1)
        #expect(model.photos.allSatisfy { $0.id != removed })
        #expect(model.thumbnails[removed] == nil)
        #expect(model.announcement == "Photo supprimée")
        #expect(model.canAdd)
        #expect(try await service.photos(for: sessionID).count == 1)
    }

    @Test func announcementSerialChangesOnEveryAnnouncement() async throws {
        let model = makeModel()
        let initial = model.announcementSerial
        await model.add([TestImages.jpeg()])
        let afterFirst = model.announcementSerial
        await model.add([TestImages.jpeg()])
        #expect(initial != afterFirst && afterFirst != model.announcementSerial)
        #expect(model.announcement == "Photo ajoutée")
    }

    @Test func imageOfReturnsTheFullImage() async throws {
        let model = makeModel()
        await model.add([TestImages.jpeg()])
        let data = await model.image(of: model.photos[0].id)
        #expect(data?.isEmpty == false)
        #expect(await model.image(of: UUID()) == nil)
    }

    @Test func spokenLabelsMatchTheSpec() async throws {
        let model = makeModel()
        await model.add(Array(repeating: TestImages.jpeg(), count: 4))
        #expect(model.spokenLabel(of: model.photos[1]) == "Photo 2 sur 4, ajoutée à 18 h 42")
        #expect(model.spokenLabel(of: model.photos[3]) == "Photo 4 sur 4, ajoutée à 18 h 42")
    }

    @Test func isAddingIsTrueWhileALoaderIsSuspended() async throws {
        let model = makeModel()
        let gate = LoaderGate()
        let task = Task { await model.add(loading: [{ await gate.wait(); return TestImages.jpeg() }]) }
        while !(await gate.isWaiting) { await Task.yield() }
        #expect(model.isAdding)
        #expect(model.photos.isEmpty)
        await gate.open()
        await task.value
        #expect(!model.isAdding)
        #expect(model.photos.count == 1)
        #expect(model.announcement == "Photo ajoutée")
    }

    @Test func loadersBeyondTheLimitAreNeverCalled() async throws {
        try await seed(5)
        let model = makeModel()
        await model.load()
        let calls = CallCounter()
        let loader: @Sendable () async -> Data? = { await calls.increment(); return TestImages.jpeg() }
        await model.add(loading: [loader, loader, loader])
        #expect(await calls.count == 1)
        #expect(model.photos.count == 6)
        #expect(model.errorMessage == "6 photos au maximum par séance : 2 n'ont pas été ajoutées.")
    }

    @Test func aLoaderThatReturnsNothingCountsAsUnreadable() async throws {
        let model = makeModel()
        await model.add(loading: [{ nil }, { TestImages.jpeg() }])
        #expect(model.photos.count == 1)
        #expect(model.errorMessage == "Une image n'a pas pu être lue.")
        #expect(!model.isAdding)
    }

    @Test func unreadableFullImageReportsAnErrorAndReturnsNil() async throws {
        let repository = ImageFailingRepository()
        let failing = SessionPhotosModel(
            service: SessionPhotoService(repository: repository, timeZone: .gmt, now: { .now }), sessionID: sessionID,
            calendar: calendar)
        #expect(await failing.image(of: UUID()) == nil)
        #expect(failing.errorMessage == "La photo n'a pas pu être ouverte.")
    }
}

private actor CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

/// Un dépôt dont la lecture d'une image échoue.
private struct ImageFailingRepository: SessionPhotoRepository {
    struct Failure: Error {}

    func photos(for sessionID: UUID) async throws -> [SessionPhoto] { [] }
    func image(of photoID: UUID) async throws -> PhotoImage? { throw Failure() }
    func add(_ photo: SessionPhoto, image: PhotoImage) async throws {}
    func delete(photoID: UUID) async throws {}
    func deleteAll(sessionID: UUID) async throws {}
}
