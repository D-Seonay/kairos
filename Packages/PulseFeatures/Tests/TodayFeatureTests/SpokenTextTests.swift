import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing
@testable import TodayFeature

/// Les textes que VoiceOver lit sur l'accueil : des fonctions pures, sans tiret, sans « bpm », « kg » ni « tilde ».
struct SpokenTextTests {
    // MARK: - Séance du jour

    private func summary(sets: Int = 19, minutes: Int = 55, rpe: Double = 8, muscles: [Muscle] = [.chest, .triceps, .frontDelts])
        -> SessionSummary {
        SessionSummary(setCount: sets, estimatedMinutes: minutes, maxRPE: rpe, topMuscles: muscles, muscleWeights: [:])
    }

    @Test func sessionSummaryIsReadAsOneSentence() {
        #expect(summary().spokenText == "19 séries, environ 55 minutes, effort perçu maximal 8 sur 10, "
            + "muscles principaux : pectoraux, triceps, deltoïdes antérieurs")
    }

    @Test func sessionSummaryHandlesSingularsLongSessionsAndHalfPoints() {
        #expect(summary(sets: 1, minutes: 75, rpe: 7.5, muscles: [.biceps]).spokenText
            == "1 série, environ 1 heure 15 minutes, effort perçu maximal 7,5 sur 10, muscles principaux : biceps")
    }

    @Test func sessionSummarySkipsWhatItDoesNotKnow() {
        #expect(summary(rpe: 0, muscles: []).spokenText == "19 séries, environ 55 minutes")
    }

    @Test func sessionStatsLineAgreesInNumber() {
        #expect(summary().statsText == "19 séries · ~ 55 min · RPE max 8")
        #expect(summary(sets: 1, minutes: 75, rpe: 7.5).statsText == "1 série · ~ 1 h 15 · RPE max 7,5")
    }

    @Test func sessionSummaryNeverUsesSymbols() {
        let text = summary().spokenText
        for forbidden in ["~", "RPE", "·", "min "] { #expect(!text.contains(forbidden)) }
    }

    // MARK: - Séance faite

    @Test func doneCardSpokenStats() {
        let card = DoneCard(title: "Push", durationMinutes: 55, setCount: 18, tonnageKg: 6_420, recordCount: 2)
        #expect(card.spokenStats == "55 minutes, 18 séries, 6\u{202F}420 kilos, 2 records")
        #expect(card.spokenLabel == "Séance faite, 55 minutes, 18 séries, 6\u{202F}420 kilos, 2 records")
    }

    @Test func doneCardSpokenStatsSingularsAndNoRecord() {
        let card = DoneCard(title: "", durationMinutes: 75, setCount: 1, tonnageKg: 62.5, recordCount: 1)
        #expect(card.spokenStats == "1 heure 15 minutes, 1 série, 62,5 kilos, 1 record")
        let none = DoneCard(title: "", durationMinutes: 1, setCount: 4, tonnageKg: 1, recordCount: 0)
        #expect(none.spokenStats == "1 minute, 4 séries, 1 kilo")
    }

    // MARK: - Charge

    @Test func loadCardLabelNamesTheRatioAndTheZone() {
        let optimal = LoadCardContent.ratio(value: 1.12, valueText: "1,12", zoneTitle: "Zone optimale", advice: "")
        #expect(optimal.accessibilityLabel == "Charge d'entraînement : ratio 1,12, zone optimale")
        let risk = LoadCardContent.ratio(value: 1.7, valueText: "1,7", zoneTitle: "Risque de blessure", advice: "")
        #expect(risk.accessibilityLabel == "Charge d'entraînement : ratio 1,7, risque de blessure")
        #expect(LoadCardContent.hidden.accessibilityLabel == nil)
    }

    // MARK: - Signaux de « Pourquoi »

    @Test func signalLabelSaysOutOfOneHundred() {
        #expect(WhyContent.Signal(title: "Sommeil", score: 56).accessibilityLabel == "Sommeil, 56 sur 100")
        #expect(WhyContent.Signal(title: "FC au repos", score: 58, spokenTitle: "Fréquence cardiaque au repos").accessibilityLabel
            == "Fréquence cardiaque au repos, 58 sur 100")
    }

    // MARK: - Synchronisation

    @Test func syncLabelSaysTheTimeNaturally() {
        let calendar = TodayClock.calendar
        #expect(TodayModel.syncAccessibilityText(lastSync: nil, calendar: calendar) == "Synchro, pas encore")
        #expect(TodayModel.syncAccessibilityText(lastSync: TodayClock.date("2026-11-02T08:00"), calendar: calendar)
            == "Synchro, 8 heures")
        #expect(TodayModel.syncAccessibilityText(lastSync: TodayClock.date("2026-11-02T18:30"), calendar: calendar)
            == "Synchro, 18 heures 30")
    }

    /// Une synchro d'un autre jour dit son jour : elle ne passe pas pour celle du matin.
    @Test func syncLabelNamesTheDayWhenItIsNotToday() {
        let calendar = TodayClock.calendar
        let now = TodayClock.date("2026-11-02T09:00")
        #expect(TodayModel.syncAccessibilityText(lastSync: TodayClock.date("2026-11-02T08:00"), calendar: calendar, now: now)
            == "Synchro, 8 heures")
        #expect(TodayModel.syncAccessibilityText(lastSync: TodayClock.date("2026-11-01T18:30"), calendar: calendar, now: now)
            == "Synchro, hier, 18 heures 30")
        #expect(TodayModel.syncAccessibilityText(lastSync: TodayClock.date("2026-10-30T08:00"), calendar: calendar, now: now)
            == "Synchro, 30 octobre, 8 heures")
        #expect(TodayModel.syncDay(TodayClock.date("2026-11-02T06:00"), now: now, calendar: calendar, spoken: false) == nil)
        #expect(TodayModel.syncDay(TodayClock.date("2026-11-01T22:00"), now: now, calendar: calendar, spoken: false) == "hier")
        #expect(TodayModel.syncDay(TodayClock.date("2026-10-30T08:00"), now: now, calendar: calendar, spoken: false) == "30 oct.")
    }

    // MARK: - Annonce du score

    private func scored(_ score: Double, estimated: Bool = false) -> TodayScore {
        .scored(estimated ? WhyFixture.estimated(score: score) : WhyFixture.recovery(score: score))
    }

    @Test func aScoreThatArrivesIsAnnounced() {
        let expected = "Ton score est prêt : Récupération 58 sur 100, fatigue modérée"
        #expect(TodayModel.scoreAnnouncement(old: nil, new: scored(58)) == expected)
        #expect(TodayModel.scoreAnnouncement(old: .needsCheckIn(missing: Factor.allCases), new: scored(58)) == expected)
        #expect(TodayModel.scoreAnnouncement(old: .beforeDayStart(yesterday: nil), new: scored(58)) == expected)
    }

    @Test func anEstimatedScoreSaysSo() {
        #expect(TodayModel.scoreAnnouncement(old: .needsCheckIn(missing: Factor.allCases), new: scored(75, estimated: true))
            == "Ton score est prêt : Récupération 75 sur 100, forme normale, estimé")
    }

    @Test func aScoreThatChangesIsAnnouncedOnlyWhenItDoes() {
        #expect(TodayModel.scoreAnnouncement(old: scored(58), new: scored(72))
            == "Score mis à jour : Récupération 72 sur 100, forme normale")
        // Même note affichée et même catégorie : rien à dire.
        #expect(TodayModel.scoreAnnouncement(old: scored(58.2), new: scored(57.6)) == nil)
        #expect(TodayModel.scoreAnnouncement(old: scored(58), new: scored(58)) == nil)
        // 64,6 s'affiche « 65 » mais reste une fatigue modérée : le passage à 65 change la note affichée et la catégorie.
        #expect(TodayModel.scoreAnnouncement(old: scored(64.6), new: scored(65))
            == "Score mis à jour : Récupération 65 sur 100, forme normale")
    }

    @Test func nothingIsAnnouncedWithoutAScoredDay() {
        #expect(TodayModel.scoreAnnouncement(old: scored(58), new: nil) == nil)
        #expect(TodayModel.scoreAnnouncement(old: nil, new: nil) == nil)
        #expect(TodayModel.scoreAnnouncement(old: scored(58), new: .needsCheckIn(missing: [.sleep])) == nil)
        #expect(TodayModel.scoreAnnouncement(old: nil, new: .beforeDayStart(yesterday: WhyFixture.recovery())) == nil)
    }

    @Test func recoveryCardLabelCarriesTheMarker() {
        #expect(RecoveryCardText.gaugeLabel(recovery: WhyFixture.recovery(score: 58), marker: nil)
            == "Récupération 58 sur 100, fatigue modérée")
        #expect(RecoveryCardText.gaugeLabel(recovery: WhyFixture.recovery(score: 58), marker: "en calibration, 9 nuits")
            == "Récupération 58 sur 100, fatigue modérée, en calibration, 9 nuits")
    }

    // MARK: - Mobilité

    @Test func mobilityEndIsAnnouncedOnlyOnceOver() {
        #expect(MobilitySheet.finishedAnnouncement(isOver: false) == nil)
        #expect(MobilitySheet.finishedAnnouncement(isOver: true) == "Mobilité terminée")
    }

    // MARK: - Noms des muscles

    /// Le design system répète les noms de muscles du catalogue du contenu, sans en dépendre : cette garde les garde alignés.
    @Test(arguments: Muscle.allCases)
    func muscleMapSummaryUsesTheAppsMuscleNames(muscle: Muscle) {
        let text = MuscleMapSummary.text(levels: [muscle: .light])
        #expect(text.hasPrefix(muscle.localizedName), "\(muscle) : « \(text) » ne commence pas par « \(muscle.localizedName) »")
    }

    @Test func muscleMapSummaryFollowsTheSessionWeights() {
        let levels = MuscleIntensity.byMuscle(weights: [.chest: 10, .triceps: 5])
        #expect(MuscleMapSummary.text(levels: levels) == "Pectoraux, intensité très forte. Triceps, intensité moyenne.")
    }
}
