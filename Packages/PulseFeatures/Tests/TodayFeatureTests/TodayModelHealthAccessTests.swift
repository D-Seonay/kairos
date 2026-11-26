import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// « Connecter Apple Santé » sur la bannière du check-in, pour qui a passé l'étape Apple Santé de l'onboarding.
@MainActor
struct TodayModelHealthAccessTests {
    /// Apple Santé tant que Pulse n'a pas demandé l'accès : rien ne se lit. Une fois la demande faite, le scénario répond.
    private actor LockedHealthSource: HealthSampleSource {
        private let inner: any HealthSampleSource
        private(set) var requests = 0

        init(_ inner: any HealthSampleSource) {
            self.inner = inner
        }

        func requestAuthorization() async throws {
            requests += 1
        }

        func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
            guard requests > 0 else { throw UnavailableHealthSource.Failure.unavailable }
            return try await inner.changes(of: signal, since: anchor, from: start)
        }

        func profileHints() async throws -> HealthProfileHints {
            try await inner.profileHints()
        }
    }

    private func needsCheckIn(_ model: TodayModel) -> Bool {
        if case .needsCheckIn = model.score { return true }
        Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
        return false
    }

    @Test func connectingHealthFromTheCheckInBringsAMeasuredScore() async throws {
        let scenario = ScenarioHealthSource(scenario: .goodNight, now: TodayClock.date("2026-11-02T08:00"),
                                            calendar: TodayClock.calendar)
        let locked = LockedHealthSource(scenario)
        let fixture = TodayFixture(health: locked)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard needsCheckIn(model) else { return }
        // L'accès n'a jamais été demandé : la bannière offre de connecter Apple Santé au lieu de parler de montre.
        #expect(!model.healthAccessRequested)

        await model.connectHealth()
        #expect(await locked.requests == 1)
        #expect(fixture.once.hasHappened(.healthAccessRequest))
        #expect(model.healthAccessRequested && model.healthAccessError == nil && !model.isConnectingHealth)
        // L'accueil s'est relu comme au retour au premier plan : le score mesuré remplace le check-in, sans relancer l'app.
        guard case .scored(let recovery) = model.score else {
            Issue.record("Un score mesuré était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(!recovery.isEstimated)
    }

    @Test func theWatchBannerStaysOnceAccessWasRequested() async throws {
        let fixture = TodayFixture(scenario: .noData)
        fixture.once.record(.healthAccessRequest)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard needsCheckIn(model) else { return }
        #expect(model.healthAccessRequested)
    }

    /// Une installation d'avant ce réglage, avec des nuits déjà lues : la demande a été faite, la bannière parle de montre.
    @Test func nightsAlreadyReadCountAsARequest() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard needsCheckIn(model) else { return }
        #expect(model.healthAccessRequested)
        #expect(fixture.once.hasHappened(.healthAccessRequest))
    }

    @Test func aFailedRequestSaysSoAndKeepsTheOffer() async throws {
        let fixture = TodayFixture(scenario: .noData)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard needsCheckIn(model) else { return }
        #expect(!model.healthAccessRequested)
        await fixture.source.setFails(true)
        await model.connectHealth()
        #expect(model.healthAccessError == "Pulse n'a pas pu accéder à Apple Santé.")
        #expect(!model.healthAccessRequested && !model.isConnectingHealth)
        #expect(!fixture.once.hasHappened(.healthAccessRequest))
        // Un nouvel essai qui aboutit efface le message.
        await fixture.source.setFails(false)
        await model.connectHealth()
        #expect(model.healthAccessError == nil && model.healthAccessRequested)
    }
}
