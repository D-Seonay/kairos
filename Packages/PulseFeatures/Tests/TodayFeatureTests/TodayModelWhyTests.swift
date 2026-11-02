import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// L'écran « Pourquoi » du modèle : le contenu suit le score, le check-in du jour et le choix de la séance.
@MainActor
struct TodayModelWhyTests {
    @Test func whyFollowsTheBadNight() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let why = try #require(model.why)
        #expect(why.changes.first?.pill == "\u{2212}4")
        #expect(why.restoreTitle == "Rétablir la séance d'origine")

        await model.chooseOriginalSession(true)
        #expect(model.why?.restoreTitle == "Revenir à l'ajustée")
    }

    /// Un jour mesuré, optimal ou normal : l'écran dit les hausses de charge du jour, lues sans rien écrire.
    @Test func whyListsTheLoadIncreasesOfTheDay() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        try await fixture.adopt("ppl-3")
        let bench = ExerciseReference.content(id: "bench-press-barbell")
        let last = TodayClock.date("2026-10-28T18:00")
        let sets = (0..<4).map { index in
            WorkoutSet(order: index, exercise: bench, exerciseName: "Développé couché", setType: .working, actualWeightKg: 60,
                       actualReps: 10, rpe: 8, completedAt: last)
        }
        try await fixture.workouts.save(WorkoutSession(startedAt: last, endedAt: last.addingTimeInterval(3_600), kind: .strength,
                                                       source: .pulse, status: .completed, title: "Push", sets: sets,
                                                       createdAt: last, updatedAt: last))
        let model = fixture.makeModel()
        await model.refresh()
        let changes = try #require(model.why).changes
        let load = try #require(changes.first { $0.pill.hasPrefix("+") && $0.title.contains("kg sur 4 séries") })
        #expect(load.pill == "+2,5")
        #expect(!changes.contains { $0.title == "Charges inchangées" })
        // Rien n'a été écrit : aucune séance en cours.
        #expect(await fixture.liveSession.current() == nil)
    }

    @Test func whySaysWhenNoSetReachedTheTopOfItsRange() async throws {
        let fixture = TodayFixture(scenario: .goodNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        let changes = try #require(model.why).changes
        #expect(changes.last?.title == "Charges de la dernière fois : aucune série n'a atteint le haut de sa fourchette")
    }

    @Test func whyShowsTheAnswersJustSaved() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        model.checkIn.selection = [.sleep: 3, .pain: 3, .motivation: 3]
        await model.submitCheckIn()
        let why = try #require(model.why)
        #expect(why.signals.map(\.title) == ["Sommeil : Bon", "Courbatures et douleurs : Légères", "Motivation : Bonne"])
        #expect(why.formula == "Score = 40 % × 75 + 35 % × 75 + 25 % × 75 = 75")
    }

    @Test func whyShowsTheSavedAnswersAfterARefresh() async throws {
        let fixture = TodayFixture(scenario: .threeNights)
        try await fixture.adopt("ppl-3")
        let first = fixture.makeModel()
        await first.refresh()
        first.checkIn.selection = [.sleep: 4, .pain: 2, .motivation: 1]
        await first.submitCheckIn()

        let relaunched = fixture.makeModel()
        await relaunched.refresh()
        let why = try #require(relaunched.why)
        #expect(why.signals.map(\.title) == ["Sommeil : Excellent", "Courbatures et douleurs : Modérées", "Motivation : Faible"])
    }

    @Test func whyDisappearsAndClosesWhenTheScoreIsGone() async throws {
        let fixture = TodayFixture()
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        model.showWhy()
        #expect(model.isShowingWhy)

        fixture.clock.set("2026-11-03T03:00")
        await model.refresh()
        #expect(model.why == nil)
        #expect(!model.isShowingWhy)
    }

    @Test func restoringFromWhyChoosesTheOtherSessionAndGoesBack() async throws {
        let fixture = TodayFixture(scenario: .badNight)
        try await fixture.adopt("ppl-3")
        let model = fixture.makeModel()
        await model.refresh()
        model.showWhy()

        await model.toggleOriginalSessionFromWhy()
        #expect(model.session?.status == .restored)
        #expect(!model.isShowingWhy)

        model.showWhy()
        await model.toggleOriginalSessionFromWhy()
        #expect(model.session?.status == .adjusted)
        #expect(!model.isShowingWhy)
    }
}
