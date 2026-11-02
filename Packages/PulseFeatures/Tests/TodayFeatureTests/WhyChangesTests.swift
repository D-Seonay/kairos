import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// Une ligne par ajustement, les boutons et le jour sans rien à ajuster de l'écran « Pourquoi ».
struct WhyChangesTests {
    private typealias Change = WhyContent.Change

    private func pills(_ content: WhyContent) -> [String] {
        content.changes.map(\.pill)
    }

    // MARK: - Musculation

    @Test func fatigueChangesOnPush() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(pills(content) == ["\u{2212}4", "7,5", "+45", "="])
        #expect(content.changes[0].title == "Volume réduit de 19 à 15 séries")
        let lost = try ["bench-press-barbell", "chest-press-machine", "pec-deck-machine", "crunch-machine"].map(WhyFixture.name)
        #expect(content.changes[0].detail == "Une série en moins sur : \(lost[0]), \(lost[1]), \(lost[2]) et \(lost[3]).")
        let bench = try WhyFixture.name("bench-press-barbell")
        #expect(content.changes[1] == Change(pill: "7,5", title: "Effort plafonné à RPE 7,5",
                                             detail: "Arrête-toi deux répétitions avant l'échec sur chaque série de travail."))
        #expect(content.changes[2].title == "Repos rallongés de 45 secondes")
        #expect(content.changes[2].detail == "2 min 45 au lieu de 2 min sur \(bench).")
        #expect(content.changes[3] == Change(pill: "=", title: "Charges inchangées",
                                             detail: "Celles de ta dernière séance, sans surcharge progressive aujourd'hui."))
    }

    @Test func normalAddsRestAndKeepsTheLoads() throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: 75))
        let bench = try WhyFixture.name("bench-press-barbell")
        #expect(pills(content) == ["+15", "="])
        #expect(content.changes[0].title == "Repos rallongés de 15 secondes")
        #expect(content.changes[0].detail == "2 min 15 au lieu de 2 min sur \(bench).")
    }

    @Test func manyLostSetsOnOneExerciseSaySeveral() throws {
        let day = RoutineDay(order: 0, name: "Jambes", kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: .content(id: "bench-press-barbell"), sets: 8, repsMin: 6, repsMax: 10,
                            targetRPE: 7, restSeconds: 120)
        ])
        let content = try WhyFixture.content(WhyFixture.recovery(), plannedDay: .strength(day))
        let bench = try WhyFixture.name("bench-press-barbell")
        #expect(content.changes[0].detail == "Des séries en moins sur : \(bench).")
    }

    @Test func optimalHasNothingToLighten() throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: 95))
        #expect(content.changes == [Change(pill: "✓", title: "Rien à alléger aujourd'hui.", detail: nil)])
        #expect(content.restoreTitle == nil)
        #expect(content.primaryAction == .startSession)
    }

    @Test func overreachedStartsMobility() throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: 30))
        #expect(content.changes == [Change(
            pill: "20", title: "Séance remplacée par 20 min de mobilité ou du repos, au choix",
            detail: "La séance prévue reste disponible avec « Séance d'origine ».")])
        #expect(content.primaryAction == .startMobility)
        #expect(content.restoreTitle == "Rétablir la séance d'origine")
    }

    @Test func actionTitles() {
        #expect(WhyContent.Action.startSession.title == "Valider et démarrer")
        #expect(WhyContent.Action.startMobility.title == "Démarrer 20 min de mobilité")
    }

    // MARK: - Séance d'origine

    @Test func adjustedOffersToRestoreTheOriginal() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(content.restoreTitle == "Rétablir la séance d'origine")
        #expect(content.primaryAction == .startSession)
    }

    @Test func restoredOffersBackToAdjusted() throws {
        let content = try WhyFixture.content(WhyFixture.recovery { $0.originalSessionChosen = true })
        #expect(content.restoreTitle == "Revenir à l'ajustée")
        #expect(pills(content) == ["\u{2212}4", "7,5", "+45", "="])
    }

    @Test func restoredOverreachedStartsTheSession() throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: 30) { $0.originalSessionChosen = true })
        #expect(content.primaryAction == .startSession)
        #expect(content.restoreTitle == "Revenir à l'ajustée")
    }

    // MARK: - Course, repos, sans programme

    @Test func intervalsSwapForEasyOnFatigue() throws {
        let run = try WhyFixture.plannedDay("runner-strength", on: "2026-11-05T08:00")
        let content = try WhyFixture.content(WhyFixture.recovery(), plannedDay: run)
        #expect(content.changes == [Change(pill: "→", title: "Fractionné remplacé par une sortie facile", detail: nil)])
        #expect(content.primaryAction == nil)
        #expect(content.restoreTitle == "Rétablir la séance d'origine")
    }

    @Test func overreachedRunSuggestsRest() throws {
        let run = try WhyFixture.plannedDay("runner-strength", on: "2026-11-05T08:00")
        let content = try WhyFixture.content(WhyFixture.recovery(score: 30), plannedDay: run)
        #expect(content.changes == [Change(pill: "0", title: "Repos conseillé plutôt que la course", detail: nil)])
        #expect(content.primaryAction == nil)
    }

    @Test func optimalRunHasNothingToLighten() throws {
        let run = try WhyFixture.plannedDay("runner-strength", on: "2026-11-05T08:00")
        let content = try WhyFixture.content(WhyFixture.recovery(score: 95), plannedDay: run)
        #expect(content.changes == [Change(pill: "✓", title: "Rien à alléger aujourd'hui.", detail: nil)])
    }

    @Test func restDayHasNothingToAdjust() throws {
        let rest = try WhyFixture.plannedDay("ppl-3", on: "2026-11-03T08:00")
        let content = try WhyFixture.content(WhyFixture.recovery(), plannedDay: rest)
        #expect(content.changes == [Change(pill: "✓", title: "Pas de séance aujourd'hui : rien à ajuster.", detail: nil)])
        #expect(content.primaryAction == nil)
        #expect(content.restoreTitle == nil)
    }

    @Test func noProgramHasNothingToAdjust() throws {
        let content = try WhyFixture.content(WhyFixture.recovery(), plannedDay: .noProgram)
        #expect(content.changes == [Change(pill: "✓", title: "Pas de séance aujourd'hui : rien à ajuster.", detail: nil)])
        #expect(content.primaryAction == nil)
    }
}
