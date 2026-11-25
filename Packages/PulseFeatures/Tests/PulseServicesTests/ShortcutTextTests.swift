import Foundation
import PulseDomain
import PulseServices
import Testing

struct ShortcutTextTests {
    private typealias Fixture = SupplementFixtures
    private let morning = TestClock.date("2026-11-25T08:00")

    private func recovery(_ score: Double, _ category: RecoveryCategory, day: String = "2026-11-25T00:00", estimated: Bool = false,
                          updated: String = "2026-11-25T07:00") -> DailyRecovery {
        DailyRecovery(day: TestClock.date(day), score: score, category: category, isEstimated: estimated, calibration: .ready,
                      createdAt: TestClock.date(updated), updatedAt: TestClock.date(updated))
    }

    // MARK: - Score

    @Test func theScoreIsSaidWithItsState() {
        #expect(ShortcutText.recoveryScore(recovery(71.6, .optimal))
            == "Ton score de récupération est de 72 sur 100 : forme optimale.")
        #expect(ShortcutText.recoveryScore(recovery(58, .moderateFatigue, estimated: true))
            == "Ton score de récupération est estimé à 58 sur 100 : fatigue modérée.")
    }

    /// Le marqueur de calibration de l'accueil suit l'état ; un score estimé ne le dit pas.
    @Test func calibrationIsSaidWhenTheHomeScreenShowsIt() {
        #expect(ShortcutText.recoveryScore(recovery(64, .normal), calibration: "en calibration, 9 nuits")
            == "Ton score de récupération est de 64 sur 100 : forme normale, en calibration, 9 nuits.")
        #expect(ShortcutText.recoveryScore(recovery(58, .moderateFatigue, estimated: true), calibration: "en calibration, 9 nuits")
            == "Ton score de récupération est estimé à 58 sur 100 : fatigue modérée.")
        #expect(ShortcutText.recoveryScore(recovery(64, .normal), calibration: nil)
            == "Ton score de récupération est de 64 sur 100 : forme normale.")
    }

    @Test func noScoreYetIsSaidPlainly() {
        #expect(ShortcutText.recoveryScore(nil) == "Ton score de récupération n'est pas encore prêt. Ouvre Pulse pour le calculer.")
    }

    @Test func onlyTodaysScoreCounts() {
        let yesterday = recovery(80, .optimal, day: "2026-11-24T00:00", updated: "2026-11-24T07:00")
        let early = recovery(60, .normal, updated: "2026-11-25T06:00")
        let latest = recovery(64, .normal, updated: "2026-11-25T07:30")

        #expect(ShortcutText.todaysRecovery([yesterday], now: morning, calendar: TestClock.calendar) == nil)
        #expect(ShortcutText.todaysRecovery([yesterday, latest, early], now: morning, calendar: TestClock.calendar) == latest)
    }

    // MARK: - Compléments

    @Test func supplementRepliesSayWhatHappened() {
        #expect(ShortcutText.supplement(.taken, name: "Créatine") == "C'est noté : prise de Créatine cochée pour aujourd'hui.")
        #expect(ShortcutText.supplement(.alreadyTaken, name: "Créatine") == "La prise de Créatine est déjà cochée aujourd'hui.")
        #expect(ShortcutText.supplement(.unknown, name: "Créatine") == "Ce complément n'est plus dans Pulse.")
    }

    @Test func todaysSupplementsStillToTakeComeFirst() {
        let creatine = Fixture.supplement("Créatine", minutes: 9 * 60, order: 0)
        let magnesium = Fixture.supplement("Magnésium", minutes: 21 * 60, order: 1)
        let vitaminD = Fixture.supplement("Vitamine D", minutes: 8 * 60, order: 2)
        let iron = Fixture.supplement("Fer", order: 3)
        let items = [
            SupplementDueItem(supplement: creatine, moment: .morning, plannedMinutes: 9 * 60),
            SupplementDueItem(supplement: vitaminD, moment: .morning, plannedMinutes: 8 * 60,
                              intake: Fixture.intake(of: vitaminD, at: "2026-11-25T08:05")),
            SupplementDueItem(supplement: magnesium, moment: .evening, plannedMinutes: 21 * 60)
        ]
        let overview = SupplementOverview(day: morning, items: items, supplements: [iron, creatine, magnesium, vitaminD],
                                          regularity: [:], advice: [])

        #expect(SupplementShortcut.suggestions(overview).map(\.name) == ["Créatine", "Magnésium", "Vitamine D", "Fer"])
    }

    @Test func aSupplementIsFoundByNameWhateverTheCaseAndAccents() {
        let supplements = [Fixture.supplement("Créatine"), Fixture.supplement("Magnésium"), Fixture.supplement("Oméga-3")]

        #expect(SupplementShortcut.matching("creatine", in: supplements).map(\.name) == ["Créatine"])
        #expect(SupplementShortcut.matching("ma créatine", in: supplements).map(\.name) == ["Créatine"])
        #expect(SupplementShortcut.matching("MAGNÉ", in: supplements).map(\.name) == ["Magnésium"])
        #expect(SupplementShortcut.matching("zinc", in: supplements).isEmpty)
        #expect(SupplementShortcut.matching("  ", in: supplements).count == 3)
    }

    /// Un nom très court n'est pas cherché dans la phrase entière : « D » ne répond pas à « magnésium ».
    @Test func aVeryShortNameIsOnlyMatchedByItsOwnLetters() {
        let supplements = [Fixture.supplement("D"), Fixture.supplement("B6"), Fixture.supplement("Magnésium")]

        #expect(SupplementShortcut.matching("magnésium du soir", in: supplements).map(\.name) == ["Magnésium"])
        #expect(SupplementShortcut.matching("d", in: supplements).map(\.name) == ["D"])
        #expect(SupplementShortcut.matching("b6", in: supplements).map(\.name) == ["B6"])
    }

    /// Un raccourci enregistré avant l'archivage se résout encore, puis refuse la prise.
    @Test func anArchivedSupplementResolvesButIsRefused() {
        let creatine = Fixture.supplement("Créatine")
        var zinc = Fixture.supplement("Zinc")
        zinc.isArchived = true
        let overview = SupplementOverview(day: morning, items: [], supplements: [creatine], regularity: [:], advice: [],
                                          archived: [zinc])

        #expect(SupplementShortcut.entities(for: [zinc.id, creatine.id, UUID()], in: overview).map(\.name) == ["Créatine", "Zinc"])
        #expect(SupplementShortcut.refusal(supplementID: zinc.id, in: overview) == .unknown)
        #expect(SupplementShortcut.refusal(supplementID: UUID(), in: overview) == .unknown)
        #expect(SupplementShortcut.refusal(supplementID: creatine.id, in: overview) == nil)
    }

    @Test func aRefusedIntakeIsAlreadyTakenOrGone() {
        let creatine = Fixture.supplement("Créatine")
        #expect(SupplementShortcut.outcome(recorded: true, supplementID: creatine.id, known: []) == .taken)
        #expect(SupplementShortcut.outcome(recorded: false, supplementID: creatine.id, known: [creatine]) == .alreadyTaken)
        #expect(SupplementShortcut.outcome(recorded: false, supplementID: UUID(), known: [creatine]) == .unknown)
    }
}
