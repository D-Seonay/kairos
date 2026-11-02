import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// Un drapeau que les tâches de test lèvent quand elles ont fini.
@MainActor
private final class Flag {
    var isSet = false
}

/// Les gardes de concurrence du modèle, vérifiées par leur effet : des doublures comptent les appels et suspendent les lectures
/// ou les enregistrements, pour que le chevauchement soit certain et non dû à un hasard d'ordonnancement.
@MainActor
struct TodayModelConcurrencyTests {
    private static func scenarioSource(_ scenario: HealthScenario) -> ScenarioHealthSource {
        ScenarioHealthSource(scenario: scenario, now: TodayClock.date("2026-11-02T08:00"), calendar: TodayClock.calendar)
    }

    private static func recoveries() -> CountingRecoveryRepository {
        CountingRecoveryRepository(InMemoryRecoveryRepository(calendar: TodayClock.calendar))
    }

    /// Laisse la tâche `second` se dérouler jusqu'à ce qu'elle ait fini, ou qu'elle ait atteint la doublure (`reached`).
    private func letSecondCallRun(done: Flag, reached: () async -> Bool) async {
        while !done.isSet, !(await reached()) {
            await Task.yield()
        }
    }

    @Test func overlappingRefreshesReadTheNightsOnce() async {
        let source = CountingHealthSource(Self.scenarioSource(.goodNight))
        let gate = Gate()
        await source.hold(at: gate)
        let model = TodayFixture(health: source).makeModel()

        let first = Task { await model.refresh() }
        await gate.waitForArrival()
        #expect(model.isLoading)
        let secondDone = Flag()
        let second = Task {
            await model.refresh()
            secondDone.isSet = true
        }
        await letSecondCallRun(done: secondDone) { await source.nightReads > 1 }
        await gate.open()
        await first.value
        await second.value

        #expect(await source.nightReads == 1)
        #expect(!model.isLoading)
        guard case .scored = model.score else {
            Issue.record("Un score était attendu, obtenu \(String(describing: model.score))")
            return
        }
    }

    @Test func overlappingCheckInsSaveOnce() async {
        let recovery = Self.recoveries()
        let fixture = TodayFixture(scenario: .threeNights, recovery: recovery)
        let model = fixture.makeModel()
        await model.refresh()
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        let gate = Gate()
        await recovery.holdCheckInSaves(at: gate)

        let first = Task { await model.submitCheckIn() }
        await gate.waitForArrival()
        let secondDone = Flag()
        let second = Task {
            await model.submitCheckIn()
            secondDone.isSet = true
        }
        await letSecondCallRun(done: secondDone) { await recovery.checkInSaves > 1 }
        await gate.open()
        await first.value
        await second.value

        #expect(await recovery.checkInSaves == 1)
        guard case .scored(let estimated) = model.score else {
            Issue.record("Un score estimé était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(estimated.isEstimated)
    }

    /// Un check-in envoyé pendant une actualisation attend qu'elle finisse, et l'accueil finit sur le score estimé.
    /// Le rafraîchisseur sérialise ses opérations : l'actualisation rend son « check-in à faire » avant que le check-in
    /// ne commence. Ce test ne couvre donc pas la garde du modèle (`scoreEpoch`) : elle ne peut plus écarter une lecture
    /// périmée, et reste en défense (elle peut écarter sans dommage un résultat plus récent que le score écrit).
    @Test func checkInSubmittedDuringARefreshEndsOnTheEstimate() async {
        let recovery = Self.recoveries()
        let fixture = TodayFixture(scenario: .threeNights, recovery: recovery)
        let model = fixture.makeModel()
        await model.refresh()
        guard case .needsCheckIn = model.score else {
            Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
            return
        }

        // L'actualisation est suspendue dans le rafraîchisseur, sur la lecture du score du jour. Le check-in lancé pendant
        // ce temps passe derrière elle dans la file, puis enregistre l'estimation.
        let gate = Gate()
        await recovery.holdNextRead(at: gate)
        let staleRefresh = Task { await model.refresh() }
        await gate.waitForArrival()

        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        let checkIn = Task { await model.submitCheckIn() }
        await gate.open()
        await staleRefresh.value
        await checkIn.value

        guard case .scored(let estimated) = model.score else {
            Issue.record("Le score estimé devait rester affiché, obtenu \(String(describing: model.score))")
            return
        }
        #expect(estimated.isEstimated)
        #expect(model.marker == "Estimé")
    }
}
