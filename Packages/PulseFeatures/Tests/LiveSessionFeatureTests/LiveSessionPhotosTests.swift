import Foundation
@testable import LiveSessionFeature
import PhotosFeature
import PulseDomain
import PulseServices
import PulseTestSupport
import Testing

/// Les photos de la séance live et du récap : le même identifiant que la séance enregistrée, un seul modèle, et rien pour une
/// séance saisie après coup.
@MainActor
struct LiveSessionPhotosTests {
    @Test func livePhotosUseTheLiveSessionID() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let live = try await fixture.startedModel(LiveFixture.plankLaunch)
        let photos = try #require(live.photos)
        await photos.add([TestImages.jpeg()])
        #expect(photos.photos.count == 1)

        for set in live.session.exercises[0].sets { await live.tap(set: set.id) }
        fixture.clock.set("2026-11-02T08:10")
        let flow = FinishFlowModel(live: live, onFinished: {})
        await flow.finishTapped()
        let recap = try #require(flow.recap)
        #expect(await recap.save())

        let saved = try await fixture.workouts.sessions(from: LiveClock.date("2026-11-02T00:00"), to: .distantFuture)
        let session = try #require(saved.first)
        #expect(session.id == live.session.id)
        let stored = try await fixture.photos.photos(for: session.id)
        #expect(stored.map(\.id) == photos.photos.map(\.id))
        #expect(stored.count == 1)
    }

    @Test func recapReusesTheLiveSessionPhotosModel() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let live = try await fixture.startedModel(LiveFixture.plankLaunch)
        for set in live.session.exercises[0].sets { await live.tap(set: set.id) }
        let flow = FinishFlowModel(live: live, onFinished: {})
        await flow.finishTapped()
        let recap = try #require(flow.recap)
        #expect(recap.photos != nil)
        #expect(recap.photos === live.photos)
    }

    /// Abandonnée sans série validée, la séance n'est pas enregistrée : son modèle de photos s'arrête et ne garde rien.
    @Test func abandoningAnUnsavedSessionDiscardsItsPhotos() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let live = try await fixture.startedModel(LiveFixture.plankLaunch)
        let photos = try #require(live.photos)
        await photos.add([TestImages.jpeg()])
        let flow = FinishFlowModel(live: live, onFinished: {})
        flow.abandonTapped()
        await flow.confirm()?.value
        #expect(photos.isDiscarded)
        #expect(try await fixture.photos.photos(for: live.session.id).isEmpty)
    }

    /// Abandonnée avec des séries validées, la séance est enregistrée et garde ses photos.
    @Test func abandoningASavedSessionKeepsItsPhotos() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let live = try await fixture.startedModel(LiveFixture.plankLaunch)
        let photos = try #require(live.photos)
        await photos.add([TestImages.jpeg()])
        await live.tap(set: live.session.exercises[0].sets[0].id)
        let flow = FinishFlowModel(live: live, onFinished: {})
        flow.abandonTapped()
        await flow.confirm()?.value
        #expect(!photos.isDiscarded)
        #expect(try await fixture.photos.photos(for: live.session.id).count == 1)
    }

    /// « Abandonner » du bandeau fait le même ménage.
    @Test func abandoningFromTheBannerDiscardsUnsavedPhotos() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let coordinator = fixture.coordinator()
        await coordinator.start(LiveFixture.plankLaunch)
        let sessionID = try #require(coordinator.current?.id)
        let photos = try #require(coordinator.model().photos)
        await photos.add([TestImages.jpeg()])
        await coordinator.abandonFromBanner()
        #expect(photos.isDiscarded)
        #expect(try await fixture.photos.photos(for: sessionID).isEmpty)
    }

    @Test func noPhotosWithoutService() async throws {
        let fixture = LiveFixture()
        let live = try await fixture.startedModel(LiveFixture.plankLaunch)
        #expect(live.photos == nil)
        for set in live.session.exercises[0].sets { await live.tap(set: set.id) }
        let flow = FinishFlowModel(live: live, onFinished: {})
        await flow.finishTapped()
        #expect(flow.recap?.photos == nil)
    }

    /// La saisie après coup n'offre pas de photos : la fabrique des séances passées ne reçoit pas le dépôt des photos, qui ne
    /// serait donc pas nettoyé si la saisie était annulée. On les ajoute depuis le détail de la séance.
    @Test func aPastEntryOffersNoPhotos() async throws {
        let fixture = LiveFixture(withPhotos: true)
        let train = fixture.environment.train
        var environment = fixture.environment
        environment.service = ActiveSessionService.pastSessions(
            workouts: train.workouts, profiles: train.profiles, settings: train.exerciseSettings,
            userExercises: train.userExercises, records: train.records, library: train.library, calendar: train.calendar,
            now: train.now)
        let coordinator = PastSessionCoordinator(environment: environment)
        let interval = DateInterval(start: LiveClock.date("2026-10-28T18:00"), end: LiveClock.date("2026-10-28T19:05"))
        await coordinator.start(SessionLaunch.past(LiveFixture.pushLaunch.day, programID: nil, interval: interval))
        let live = coordinator.model()
        #expect(live.session.isPastEntry)
        #expect(live.photos == nil)
        let flow = coordinator.finishFlow()
        await flow.finishTapped()
        await flow.confirm()?.value
        #expect(flow.recap?.photos == nil)
    }
}
