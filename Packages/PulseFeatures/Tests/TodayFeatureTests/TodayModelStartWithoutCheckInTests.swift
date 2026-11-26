import CheckInFeature
import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// « Démarrer sans check-in » : le check-in du jour n'est pas un passage obligé avant la séance.
@MainActor
struct TodayModelStartWithoutCheckInTests {
    /// Tant que le check-in du jour attend, « Démarrer sans check-in » et le contrôle « Séance du jour » lancent la séance
    /// prévue, sans ajustement : ce que l'onglet Séance lance sans score (`SessionLaunch.routine` avec `recovery: nil`).
    @Test func theCheckInDoesNotBlockTheStart() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        let program = try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard case .needsCheckIn = model.score else {
            Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(model.canStartWithoutCheckIn)
        let launch = try #require(model.shownSessionLaunch())
        let planned = try #require(model.session?.originalDay)
        #expect(launch == SessionLaunch.routine(planned, programID: program.id, recovery: nil, originalChosen: false,
                                                profile: try await fixture.profiles.load()))
        #expect(launch.day == planned && launch.applied.isEmpty && launch.refused.isEmpty)

        // Le check-in fait, « Démarrer » redevient le bouton de la séance, ajustée par le score estimé.
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        await model.submitCheckIn()
        #expect(!model.canStartWithoutCheckIn)
        #expect(model.shownSessionLaunch() != nil)
    }

    /// Un jour de repos, le check-in attend sans rien à démarrer.
    @Test func nothingStartsWithoutCheckInOnARestDay() async throws {
        let fixture = TodayFixture(scenario: .threeNights, at: "2026-11-03T08:00")
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        guard case .needsCheckIn = model.score else {
            Issue.record("Un check-in était attendu, obtenu \(String(describing: model.score))")
            return
        }
        #expect(!model.canStartWithoutCheckIn)
        #expect(model.shownSessionLaunch() == nil)
    }
}
