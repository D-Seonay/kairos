import Foundation
@testable import PhotosFeature
import PulseDomain
import PulseServices
import PulseTestSupport
import Testing

/// Une séance abandonnée sans être enregistrée pendant un ajout de photos : rien ne doit rester dans iCloud.
@MainActor
struct SessionPhotosDiscardTests {
    private let sessionID = UUID()

    private func service(_ repository: any SessionPhotoRepository) -> SessionPhotoService {
        SessionPhotoService(repository: repository, timeZone: .gmt, now: { PhotosTestClock.date("2026-08-01T18:42") })
    }

    /// Une image encore en chargement quand la séance est abandonnée : ni elle ni la photo déjà ajoutée ne restent.
    @Test func discardDuringALoadKeepsNothing() async throws {
        let repository = InMemorySessionPhotoRepository()
        let model = SessionPhotosModel(service: service(repository), sessionID: sessionID, calendar: PhotosTestClock.calendar)
        let gate = LoaderGate()
        let first: @Sendable () async -> Data? = { TestImages.jpeg() }
        let gated: @Sendable () async -> Data? = {
            await gate.wait()
            return TestImages.jpeg()
        }
        let third: @Sendable () async -> Data? = { TestImages.jpeg() }
        let adding = Task { await model.add(loading: [first, gated, third]) }
        while await !gate.isWaiting { await Task.yield() }
        #expect(model.photos.count == 1)

        await model.discard()
        await gate.open()
        await adding.value
        #expect(model.photos.isEmpty)
        #expect(try await repository.photos(for: sessionID).isEmpty)
        #expect(model.announcement == nil && model.errorMessage == nil)
        #expect(!model.isAdding && !model.canAdd)
    }

    /// Une photo dont l'écriture finit après l'abandon est supprimée aussitôt écrite.
    @Test func photoWrittenDuringTheDiscardIsDeleted() async throws {
        let repository = GatedSessionPhotoRepository()
        let model = SessionPhotosModel(service: service(repository), sessionID: sessionID, calendar: PhotosTestClock.calendar)
        let adding = Task { await model.add([TestImages.jpeg()]) }
        while await !repository.isAdding { await Task.yield() }

        // L'abandon attend dans la file du service que l'ajout commencé finisse.
        let discarding = Task { await model.discard() }
        while !model.isDiscarded { await Task.yield() }
        await repository.open()
        await discarding.value
        await adding.value
        #expect(try await repository.photos(for: sessionID).isEmpty)
        #expect(model.photos.isEmpty)
        // Idempotent : un second appel ne change rien.
        await model.discard()
        #expect(try await repository.photos(for: sessionID).isEmpty)
    }

    /// `discard` ne touche qu'à la séance du modèle.
    @Test func discardLeavesOtherSessionsAlone() async throws {
        let repository = InMemorySessionPhotoRepository()
        let photos = service(repository)
        let other = UUID()
        _ = try await photos.add(TestImages.jpeg(), to: other)
        _ = try await photos.add(TestImages.jpeg(), to: sessionID)
        let model = SessionPhotosModel(service: photos, sessionID: sessionID, calendar: PhotosTestClock.calendar)
        await model.load()
        await model.discard()
        #expect(try await repository.photos(for: sessionID).isEmpty)
        #expect(try await repository.photos(for: other).count == 1)
    }
}
