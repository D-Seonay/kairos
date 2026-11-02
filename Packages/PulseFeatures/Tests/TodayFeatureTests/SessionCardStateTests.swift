import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

/// La carte « Séance du jour » selon la séance et le score : PPL 3 (lundi 2 novembre = Push, mardi = repos),
/// runner-strength pour la course (jeudi 5 novembre = Fractionné).
struct SessionCardStateTests {
    private let library = ContentLibrary.bundled
    private var directory: ExerciseDirectory { ExerciseDirectory(library: library, userExercises: []) }

    private func plan(_ templateID: String, on text: String) throws -> PlannedDay {
        let now = TodayClock.date(text)
        let template = try #require(library.programTemplate(id: templateID))
        let program = ProgramAdopter(library: library).adopt(template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: now)
        return TodayPlanner.plan(program: program, on: now, calendar: TodayClock.calendar)
    }

    private func recovery(_ score: Double, originalChosen: Bool? = nil) -> DailyRecovery {
        let now = TodayClock.date("2026-11-02T08:00")
        return DailyRecovery(day: TodayClock.date("2026-11-02T00:00"), score: score, category: RecoveryCategory(score: score),
                             isEstimated: false, calibration: .ready, originalSessionChosen: originalChosen,
                             createdAt: now, updatedAt: now)
    }

    /// La carte d'une séance prévue `on`, sous un score du jour `score`.
    private func card(_ templateID: String = "ppl-3", on text: String = "2026-11-02T08:00", score: Double,
                      originalChosen: Bool? = nil) throws -> SessionCardState {
        let scored = recovery(score, originalChosen: originalChosen)
        let session = TodaySession(plannedDay: try plan(templateID, on: text), recovery: scored)
        return SessionCardState.make(session: session, score: .scored(scored), directory: directory)
    }

    private func strength(_ state: SessionCardState) -> StrengthCard? {
        if case .strength(let card) = state { return card }
        Issue.record("Une carte de musculation était attendue, obtenu \(state)")
        return nil
    }

    @Test func fatigueOnPushIsAnAdjustedCard() throws {
        let card = try #require(strength(try card(score: 50)))
        #expect(card.title == "Push, volume allégé")
        #expect(card.badge == .adjusted)
        #expect(card.summary.setCount == 15)
        #expect(card.showsWhy)
        #expect(card.originButton == "Séance d'origine")
        #expect(card.startButton == "Démarrer la séance")
    }

    @Test func restoredCardOffersBackToAdjusted() throws {
        let card = try #require(strength(try card(score: 50, originalChosen: true)))
        #expect(card.title == "Push")
        #expect(card.badge == .planned)
        #expect(card.summary.setCount == 19)
        #expect(card.showsWhy)
        #expect(card.originButton == "Revenir à l'ajustée")
        #expect(card.startButton == "Démarrer quand même")
    }

    @Test func optimalCardIsPlannedWithoutWhy() throws {
        let card = try #require(strength(try card(score: 94)))
        #expect(card.title == "Push")
        #expect(card.badge == .planned)
        #expect(card.summary.setCount == 19)
        #expect(!card.showsWhy)
        #expect(card.originButton == nil)
        #expect(card.startButton == "Démarrer la séance")
    }

    /// Avant 4 h, aucun score du jour : même une séance construite sur le score de la veille reste planifiée,
    /// sans « Séance d'origine » (le choix serait refusé, faute de score aujourd'hui).
    @Test func beforeFourTheCardIsPlanned() throws {
        let yesterday = recovery(50)
        let session = TodaySession(plannedDay: try plan("ppl-3", on: "2026-11-02T03:00"), recovery: yesterday)
        let state = SessionCardState.make(session: session, score: .beforeDayStart(yesterday: yesterday), directory: directory)
        let card = try #require(strength(state))
        #expect(card.title == "Push")
        #expect(card.badge == .planned)
        #expect(card.summary.setCount == 19)
        #expect(!card.showsWhy)
        #expect(card.originButton == nil)
        #expect(card.startButton == "Démarrer la séance")
    }

    @Test func overreachedProposesMobilityOrRest() throws {
        #expect(try card(score: 30) == .mobilityOrRest(dayName: "Push"))
    }

    @Test func overreachedRestoredShowsTheOriginal() throws {
        let card = try #require(strength(try card(score: 30, originalChosen: true)))
        #expect(card.title == "Push")
        #expect(card.badge == .planned)
        #expect(card.summary.setCount == 19)
        #expect(card.showsWhy)
        #expect(card.originButton == "Revenir à l'ajustée")
        #expect(card.startButton == "Démarrer quand même")
    }

    @Test func intervalsUnderFatigueSuggestAnEasyRun() throws {
        let state = try card("runner-strength", on: "2026-11-05T08:00", score: 50)
        #expect(state == .run(RunCard(
            title: "Fractionné", target: "30 min",
            suggestion: "Fatigue modérée : remplace le fractionné par une sortie facile de même durée.")))
    }

    @Test func overreachedRunSuggestsRest() throws {
        let state = try card("runner-strength", on: "2026-11-05T08:00", score: 30)
        #expect(state == .run(RunCard(
            title: "Fractionné", target: "30 min", suggestion: "Surmenage : repos conseillé aujourd'hui, la course peut attendre.")))
    }

    @Test func easyRunUnderFatigueKeepsTheRun() throws {
        let state = try card("runner-strength", on: "2026-11-02T08:00", score: 50)
        #expect(state == .run(RunCard(title: "Sortie facile", target: "40 min", suggestion: nil)))
    }

    @Test func restDaySuggestsMobilityUnder65() throws {
        let rest = try plan("ppl-3", on: "2026-11-03T08:00")
        guard case .rest(let next) = rest else {
            Issue.record("Un repos était attendu, obtenu \(rest)")
            return
        }
        #expect(next?.weekday == .wednesday)
        func state(_ score: TodayScore) -> SessionCardState {
            let scored: DailyRecovery? = if case .scored(let recovery) = score { recovery } else { nil }
            return SessionCardState.make(session: TodaySession(plannedDay: rest, recovery: scored), score: score, directory: directory)
        }
        #expect(state(.scored(recovery(58))) == .rest(next: next, suggestsMobility: true))
        // 64,6 s'affiche « 65 » mais reste une fatigue modérée : la suggestion suit le score brut.
        #expect(state(.scored(recovery(64.6))) == .rest(next: next, suggestsMobility: true))
        #expect(state(.scored(recovery(65))) == .rest(next: next, suggestsMobility: false))
        #expect(state(.scored(recovery(70))) == .rest(next: next, suggestsMobility: false))
        #expect(state(.needsCheckIn(missing: Factor.allCases)) == .rest(next: next, suggestsMobility: false))
    }

    // MARK: - Séance faite ou en cours

    private let doneCard = DoneCard(title: "Push", durationMinutes: 55, setCount: 18, tonnageKg: 6_420, recordCount: 2)

    private func card(_ templateID: String = "ppl-3", on text: String = "2026-11-02T08:00", score: Double,
                      done: DoneCard? = nil, inProgress: String? = nil) throws -> SessionCardState {
        let scored = recovery(score)
        let session = TodaySession(plannedDay: try plan(templateID, on: text), recovery: scored)
        return SessionCardState.make(session: session, score: .scored(scored), directory: directory, done: done,
                                     inProgressTitle: inProgress)
    }

    @Test func aDoneSessionReplacesTheStrengthCard() throws {
        #expect(try card(score: 94, done: doneCard) == .done(doneCard))
        #expect(try card(score: 50, done: doneCard) == .done(doneCard))
    }

    @Test func aRunningSessionWinsOverEverything() throws {
        #expect(try card(score: 94, done: doneCard, inProgress: "Push") == .inProgress(title: "Push"))
        #expect(try card("runner-strength", on: "2026-11-05T08:00", score: 50, inProgress: "Séance libre")
            == .inProgress(title: "Séance libre"))
        #expect(try card(score: 30, inProgress: "Push") == .inProgress(title: "Push"))
    }

    /// Un bilan ne remplace que « Démarrer » : un jour de repos garde sa carte.
    @Test func aDoneSessionLeavesARestDayAlone() throws {
        let state = try card(on: "2026-11-03T08:00", score: 80, done: doneCard)
        guard case .rest = state else {
            Issue.record("Un repos était attendu, obtenu \(state)")
            return
        }
    }

    @Test func doneCardTexts() {
        #expect(doneCard.durationText == "55 min")
        #expect(doneCard.setsText == "18 séries")
        #expect(doneCard.tonnageText == "6420 kg")
        #expect(doneCard.recordsText == "2 records")
        #expect(DoneCard(title: "", durationMinutes: 60, setCount: 1, tonnageKg: 80.5, recordCount: 1).setsText == "1 série")
        #expect(DoneCard(title: "", durationMinutes: 60, setCount: 1, tonnageKg: 80.5, recordCount: 1).recordsText == "1 record")
        #expect(DoneCard(title: "", durationMinutes: 60, setCount: 1, tonnageKg: 80.5, recordCount: 0).recordsText == nil)
        #expect(DoneCard(title: "", durationMinutes: 75, setCount: 1, tonnageKg: 80.5, recordCount: 0).durationText == "1 h 15")
    }

    @Test func noProgramCard() {
        let session = TodaySession(plannedDay: .noProgram, recovery: recovery(50))
        #expect(SessionCardState.make(session: session, score: .scored(recovery(50)), directory: directory) == .noProgram)
    }
}
