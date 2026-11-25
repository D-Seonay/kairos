import Foundation
import PhotosFeature
import PulseDomain
import PulseServices
import PulseTestSupport
@testable import RunFeature
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RunModelTests {
    @Test func locationDeniedShowsTheNotice() async throws {
        let fixture = RunFeatureFixture(location: StubRunLocationTracker(state: .denied))
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        #expect(model.locationNotice == nil)
        // Au départ : le flux du signal se termine aussitôt, sans valeur.
        await model.watchGPS()
        #expect(model.locationNotice == "Localisation refusée : seul le temps est enregistré.")
        // Pendant la course : l'état vient de la course.
        await model.start()
        #expect(model.snapshot?.locationDenied == true)
        #expect(model.locationNotice == "Localisation refusée : seul le temps est enregistré.")
    }

    /// « Position exacte » coupée : l'écran l'explique au départ et pendant la course, au lieu de « Signal faible » seul, et
    /// le retour dans l'app après les réglages relit la précision.
    @Test func approximateLocationExplainsItself() async throws {
        let location = StubRunLocationTracker(accuracyReduced: true)
        let fixture = RunFeatureFixture(location: location)
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        #expect(model.approximateNotice == nil)
        let watching = Task { await model.watchGPS() }
        await model.refreshLocationAccuracy()
        #expect(model.approximateNotice?.hasPrefix("Position précise désactivée") == true)
        #expect(model.locationNotice == nil)
        await model.start()
        await watching.value
        #expect(model.approximateNotice != nil)

        await location.setAccuracyReduced(false)
        await model.refreshLocationAccuracy()
        #expect(model.approximateNotice == nil)
    }

    /// Localisation refusée : la ligne du refus suffit, la précision n'est pas expliquée en plus.
    @Test func deniedLocationIsNotCalledApproximate() async throws {
        let fixture = RunFeatureFixture(location: StubRunLocationTracker(state: .denied, accuracyReduced: true))
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.watchGPS()
        await model.refreshLocationAccuracy()
        #expect(model.locationNotice != nil)
        #expect(model.approximateNotice == nil)
    }

    @Test func grantedLocationShowsNoNotice() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        #expect(model.snapshot?.locationDenied == false)
        #expect(model.locationNotice == nil)
    }

    @Test func startShowsTheRunAndFinishOpensTheRecap() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(RunLaunch(title: "Footing facile", targetMinutes: 30))
        let model = coordinator.model()
        #expect(model.launch?.title == "Footing facile")
        await model.start()
        #expect(model.phase == .running)
        #expect(coordinator.current != nil)
        await model.pause()
        #expect(coordinator.current?.isPaused == true)
        await model.resume()
        #expect(coordinator.current?.isPaused == false)
        await model.finish()
        let recap = try #require(model.recap)
        #expect(recap.data.session.title == "Footing facile")
        #expect(coordinator.current == nil)
        #expect(coordinator.isPresented)
    }

    @Test func effortStartsUnset() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        await model.finish()
        let recap = try #require(model.recap)
        #expect(recap.rpe == nil)
        #expect(recap.note.isEmpty)
    }

    @Test func savingRecapPassesNilWhenUnset() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        await model.finish()
        let recap = try #require(model.recap)
        let sessionID = recap.data.session.id

        recap.rpe = 8
        recap.note = "  Jambes lourdes  "
        #expect(await recap.save())
        var stored = try #require(try await fixture.workouts.session(id: sessionID))
        #expect(stored.overallRPE == 8)
        #expect(stored.note == "Jambes lourdes")

        // « Pas noté » : la séance repart sans RPE noté.
        recap.rpe = nil
        recap.note = ""
        #expect(await recap.save())
        stored = try #require(try await fixture.workouts.session(id: sessionID))
        #expect(stored.overallRPE == nil)
        #expect(stored.note == nil)
        // Enregistrer ferme la course.
        #expect(!coordinator.isPresented)
    }

    @Test func deletingTheRunRemovesItAndCloses() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        await model.finish()
        let recap = try #require(model.recap)
        #expect(await recap.delete())
        #expect(try await fixture.workouts.session(id: recap.data.session.id) == nil)
        #expect(!coordinator.isPresented)
    }

    @Test func announcementsToggleIsRemembered() {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        #expect(model.announcesKilometres)
        model.announcesKilometres = false
        #expect(!fixture.preferences.announcesKilometres)
    }

    @Test func voiceOverKilometreOnlyWithoutSpokenAnnouncements() {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        #expect(model.kilometerAnnouncement(from: 950, to: 1_010) == nil)
        model.announcesKilometres = false
        #expect(model.kilometerAnnouncement(from: 950, to: 1_010) == "1 kilomètre")
        #expect(model.kilometerAnnouncement(from: 1_010, to: 1_200) == nil)
    }

    @Test func cancellingTheStartScreenCloses() async {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().cancel()
        #expect(!coordinator.isPresented)
        #expect(await fixture.service.current() == nil)
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RunRecapPhotosTests {
    @Test func runRecapPhotosUseTheRunSessionID() async throws {
        let fixture = RunFeatureFixture(withPhotos: true)
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        await model.finish()
        let recap = try #require(model.recap)
        let photos = try #require(recap.photos)

        await photos.add([TestImages.jpeg()])

        let stored = try await fixture.photos.photos(for: recap.data.session.id)
        #expect(stored.count == 1)
        #expect(photos.photos.map(\.id) == stored.map(\.id))
    }

    @Test func runRecapHasNoPhotosWithoutService() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        let model = coordinator.model()
        await model.start()
        await model.finish()
        #expect(try #require(model.recap).photos == nil)
    }
}
