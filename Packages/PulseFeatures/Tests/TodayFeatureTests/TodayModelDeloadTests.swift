import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// La semaine de décharge vue de l'accueil (spec M6 §10). Lundi 2 novembre, PPL 3 : Push.
@MainActor
struct TodayModelDeloadTests {
    /// Trois semaines calmes de 30 min, puis sept jours de 120 min jusqu'à hier : le ratio dépasse 1,5 hier et aujourd'hui.
    private func logRisingLoad(_ fixture: TodayFixture) async throws {
        let calendar = TodayClock.calendar
        let start = TodayClock.date("2026-10-05T18:00")
        for offset in 0..<28 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let minutes: Double = offset < 21 ? 30 : 120
            try await fixture.workouts.save(WorkoutSession(
                startedAt: date, kind: .strength, source: .pulse, status: .completed, title: "Séance", overallRPE: 6,
                durationMinutes: minutes, createdAt: date, updatedAt: date))
        }
    }

    @Test func aRisingLoadOffersADeload() async throws {
        let fixture = TodayFixture()
        try await fixture.adopt("ppl-3")
        try await logRisingLoad(fixture)
        let model = fixture.makeModel()
        await model.refresh()
        let offer = try #require(model.deloadOffer)
        #expect(offer.ratio >= 1.5)
        #expect(DeloadOfferCard.message(offer).contains("deux jours de suite"))
    }

    @Test func acceptingLightensTheCardAndTheLaunch() async throws {
        let fixture = TodayFixture()
        try await fixture.adopt("ppl-3")
        try await logRisingLoad(fixture)
        let model = fixture.makeModel()
        await model.refresh()
        let planned = try #require(model.session?.originalDay).exercises.reduce(0) { $0 + $1.sets }

        await model.decideDeload(true)
        #expect(model.deloadOffer == nil)
        guard case .strength(let card) = model.card else {
            Issue.record("Une carte de musculation était attendue, obtenu \(model.card)")
            return
        }
        #expect(card.badge == .deload && card.title == "Push, décharge")
        #expect(card.summary.setCount < planned)
        let launch = try #require(model.sessionLaunch(startsOriginal: false))
        #expect(launch.loadFactor == 0.9 && launch.applied.first?.kind == .deload)
    }

    @Test func decliningHidesTheOfferUntilSunday() async throws {
        let fixture = TodayFixture()
        try await fixture.adopt("ppl-3")
        try await logRisingLoad(fixture)
        let model = fixture.makeModel()
        await model.refresh()
        await model.decideDeload(false)
        #expect(model.deloadOffer == nil && model.session?.isDeload == false)
        #expect(model.sessionLaunch(startsOriginal: false)?.refused.first?.kind == .deload)
    }
}
