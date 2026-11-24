import Foundation
import PulseDomain
import PulseServices
@testable import RunFeature
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RunCoordinatorTests {
    @Test func refusesWhileStrengthSessionIsActive() {
        let fixture = RunFeatureFixture(strengthActive: true)
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        #expect(!coordinator.isPresented)
        #expect(coordinator.errorMessage == "Une séance de musculation est en cours.")
    }

    @Test func prepareOpensTheStartScreen() {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        #expect(coordinator.isPresented)
        #expect(coordinator.errorMessage == nil)
        #expect(coordinator.model() === coordinator.model())
        #expect(coordinator.model().phase == .start(.free()))
    }

    @Test func refreshPresentsAReattachedRun() async throws {
        let draft = RunFeatureFixture.interruptedDraft()
        let fixture = RunFeatureFixture(recorder: StubRunWorkoutRecorder(recoverable: true), draft: draft)
        let coordinator = fixture.coordinator()
        await coordinator.refresh()
        #expect(coordinator.isPresented)
        #expect(coordinator.recovery == nil)
        #expect(coordinator.current?.sessionID == draft.sessionID)
        #expect(coordinator.model().phase == .running)
    }

    @Test func refreshOffersAnInterruptedRun() async throws {
        let draft = RunFeatureFixture.interruptedDraft()
        let fixture = RunFeatureFixture(draft: draft)
        let coordinator = fixture.coordinator()
        await coordinator.refresh()
        #expect(!coordinator.isPresented)
        #expect(coordinator.current == nil)
        let offer = try #require(coordinator.recovery)
        #expect(offer.sessionID == draft.sessionID)
        #expect(!offer.isStillRecording)

        // « Enregistrer » sauve la course interrompue et ouvre son récap.
        await coordinator.saveInterruptedRun()
        #expect(coordinator.recovery == nil)
        #expect(coordinator.isPresented)
        #expect(coordinator.model().recap?.data.session.id == draft.sessionID)
    }

    @Test func discardingAnInterruptedRunKeepsNothing() async throws {
        let fixture = RunFeatureFixture(draft: RunFeatureFixture.interruptedDraft())
        let coordinator = fixture.coordinator()
        await coordinator.refresh()
        await coordinator.discardInterruptedRun()
        #expect(coordinator.recovery == nil)
        #expect(!coordinator.isPresented)
        #expect(try await fixture.drafts.load() == nil)
    }

    @Test func refreshExposesForgottenEnd() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        await coordinator.refresh()
        #expect(coordinator.forgottenEnd == nil)

        fixture.clock.advance(minutes: 31)
        await coordinator.refresh()
        #expect(coordinator.forgottenEnd == RunFeatureFixture.start)

        // « Terminer » clôt la course à l'heure du dernier déplacement.
        await coordinator.finishAtForgottenEnd()
        #expect(coordinator.forgottenEnd == nil)
        #expect(coordinator.current == nil)
        #expect(coordinator.model().recap?.data.session.endedAt == RunFeatureFixture.start)
    }

    @Test func dismissingForgottenEndKeepsTheRun() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        fixture.clock.advance(minutes: 31)
        await coordinator.refresh()
        coordinator.dismissForgotten()
        #expect(coordinator.forgottenEnd == nil)
        #expect(coordinator.current != nil)
    }

    @Test func refreshClosesARunFinishedElsewhere() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        _ = try await fixture.service.finish()
        await coordinator.refresh()
        #expect(coordinator.current == nil)
        #expect(!coordinator.isPresented)
    }

    @Test func prepareWithARunInProgressPresentsIt() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        coordinator.isPresented = false
        coordinator.prepare(RunLaunch(title: "Autre"))
        #expect(coordinator.isPresented)
        #expect(coordinator.model().phase == .running)
    }

    @Test func snapshotsFollowTheService() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        // Une pause décidée ailleurs (Live Activity) arrive par le flux des états.
        await fixture.service.pause()
        try await waitUntil { coordinator.current?.isPaused == true }
        #expect(coordinator.current?.isPaused == true)
    }

    /// Attend qu'une condition devienne vraie, en rendant la main entre deux lectures.
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<500 where !condition() {
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}
