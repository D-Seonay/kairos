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

    /// Un enregistrement qui échoue garde l'offre, pour que l'alerte revienne, et le dit.
    @Test func failedInterruptedSaveKeepsTheOffer() async throws {
        let fixture = RunFeatureFixture(draft: RunFeatureFixture.interruptedDraft())
        let coordinator = fixture.coordinator()
        await coordinator.refresh()
        let offer = try #require(coordinator.recovery)
        // Le brouillon a disparu entre l'alerte et « Enregistrer » : le service n'a rien à enregistrer.
        try await fixture.drafts.clear()
        await coordinator.saveInterruptedRun()
        #expect(coordinator.recovery == offer)
        #expect(coordinator.errorMessage == "Pulse n'a pas pu enregistrer la course interrompue.")
        #expect(!coordinator.isPresented)
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

        // Sans aucun point retenu (position approximative, pas de signal), rien ne dit que la course est oubliée : l'alerte
        // proposait avant de la terminer au départ, soit ~0 min, pendant que le coureur courait. Plus d'alerte.
        fixture.clock.advance(minutes: 31)
        await coordinator.refresh()
        #expect(coordinator.forgottenEnd == nil)

        // Un point retenu, puis 31 min sans bouger : l'alerte propose de terminer à ce point.
        let fix = try await pushFix(fixture)
        fixture.clock.advance(minutes: 31)
        await coordinator.refresh()
        #expect(coordinator.forgottenEnd == fix)

        // « Terminer » clôt la course à l'heure du dernier déplacement.
        await coordinator.finishAtForgottenEnd()
        #expect(coordinator.forgottenEnd == nil)
        #expect(coordinator.current == nil)
        #expect(coordinator.model().recap?.data.session.endedAt == fix)
    }

    /// Un point précis livré maintenant, attendu jusqu'à son traitement par le service ; rend son heure.
    private func pushFix(_ fixture: RunFeatureFixture) async throws -> Date {
        let now = fixture.clock.now
        await fixture.location.push(RunTrackPoint(timestamp: now, latitude: 48.8566, longitude: 2.3522, horizontalAccuracy: 5))
        for _ in 0..<500 {
            if await fixture.service.current()?.gps == .ready { return now }
            try await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Le point n'a jamais été traité")
        return now
    }

    @Test func refreshExposesForgottenEndAfterReattach() async throws {
        // Un point tous les 2 s, à 6 m du précédent : le dernier déplacement est à la 60e seconde.
        let start = RunFeatureFixture.start
        let points = stride(from: 0, through: 60, by: 2).map { second in
            RunTrackPoint(timestamp: start.addingTimeInterval(Double(second)),
                          latitude: 48.8566 + Double(second) * 3 / 111_195, longitude: 2.3522, horizontalAccuracy: 5)
        }
        let draft = RunDraft(sessionID: UUID(), launch: .free(), startedAt: start, points: points,
                             updatedAt: start.addingTimeInterval(60))
        let fixture = RunFeatureFixture(recorder: StubRunWorkoutRecorder(recoverable: true), draft: draft)
        fixture.clock.advance(minutes: 32)
        let coordinator = fixture.coordinator()
        await coordinator.refresh()
        #expect(coordinator.isPresented)
        #expect(coordinator.current?.sessionID == draft.sessionID)
        #expect(coordinator.forgottenEnd == start.addingTimeInterval(60))
    }

    @Test func dismissingForgottenEndKeepsTheRun() async throws {
        let fixture = RunFeatureFixture()
        let coordinator = fixture.coordinator()
        coordinator.prepare(.free())
        await coordinator.model().start()
        _ = try await pushFix(fixture)
        fixture.clock.advance(minutes: 31)
        await coordinator.refresh()
        #expect(coordinator.forgottenEnd != nil)
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
