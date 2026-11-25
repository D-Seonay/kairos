import Foundation
@testable import OnboardingFeature
import PulseDomain
import Testing

/// Les textes lus par VoiceOver à l'onboarding : l'annonce du score, les champs et les pilules.
@MainActor
struct OnboardingSpokenTests {
    private func recovery(
        score: Double = 58, category: RecoveryCategory = .moderateFatigue, isEstimated: Bool = false,
        calibration: CalibrationState = .ready
    ) -> DailyRecovery {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        return DailyRecovery(
            day: day, score: score, category: category, isEstimated: isEstimated, calibration: calibration,
            createdAt: day, updatedAt: day)
    }

    // MARK: - Score

    @Test func scoreReadyAnnouncementSaysScoreAndCategory() {
        #expect(OnboardingCopy.scoreReadyAnnouncement(recovery: recovery()) == "Ton score est prêt : 58 sur 100, fatigue modérée")
    }

    @Test func scoreReadyAnnouncementRoundsAndClamps() {
        #expect(OnboardingCopy.scoreReadyAnnouncement(recovery: recovery(score: 57.6, category: .moderateFatigue))
            == "Ton score est prêt : 58 sur 100, fatigue modérée")
        #expect(OnboardingCopy.scoreReadyAnnouncement(recovery: recovery(score: 104, category: .optimal))
            == "Ton score est prêt : 100 sur 100, forme optimale")
    }

    @Test func scoreReadyAnnouncementSaysWhenEstimated() {
        let estimated = recovery(score: 71, category: .normal, isEstimated: true)
        #expect(OnboardingCopy.scoreReadyAnnouncement(recovery: estimated) == "Ton score est prêt : 71 sur 100, forme normale, estimé")
    }

    @Test func scoreAccessibilityMergesTitleGaugeAndMarker() {
        #expect(OnboardingCopy.scoreAccessibility(recovery: recovery())
            == "Ta récupération ce matin : 58 sur 100, fatigue modérée")
        let estimated = recovery(isEstimated: true)
        #expect(OnboardingCopy.scoreAccessibility(recovery: estimated)
            == "Ta récupération ce matin : 58 sur 100, fatigue modérée, estimé")
    }

    @Test func scoreAccessibilitySpeaksTheCalibrationNights() {
        let calibrating = recovery(calibration: .calibrating(nights: 9))
        #expect(OnboardingCopy.scoreAccessibility(recovery: calibrating)
            == "Ta récupération ce matin : 58 sur 100, fatigue modérée, en calibration, 9 nuits")
        let first = recovery(calibration: .calibrating(nights: 1))
        #expect(OnboardingCopy.scoreAccessibility(recovery: first).hasSuffix("en calibration, 1 nuit"))
    }

    // MARK: - Champs

    @Test func measureLabelSpeaksTheUnit() {
        #expect(OnboardingCopy.measureLabel(title: "Taille", unit: .centimeters) == "Taille, en centimètres")
        #expect(OnboardingCopy.measureLabel(title: "Poids actuel", unit: .kilograms) == "Poids actuel, en kilos")
    }

    @Test func measureUnitsHaveASpokenName() {
        #expect(OnboardingCopy.MeasureUnit.centimeters.spokenName == "centimètres")
        #expect(OnboardingCopy.MeasureUnit.kilograms.spokenName == "kilos")
    }

    @Test func sessionsPerWeekLabelCountsTheSessions() {
        #expect(OnboardingCopy.sessionsPerWeekLabel(3) == "3 séances par semaine")
        #expect(OnboardingCopy.sessionsPerWeekLabel(6) == "6 séances par semaine")
        #expect(OnboardingCopy.sessionsPerWeekLabel(1) == "1 séance par semaine")
    }

    // MARK: - Aperçu de la semaine

    @Test func everyKindHasItsOwnShape() {
        #expect(WeekPreviewDay.Kind.strength.systemImage == "dumbbell.fill")
        #expect(WeekPreviewDay.Kind.run.systemImage == "figure.run")
        #expect(WeekPreviewDay.Kind.rest.systemImage == nil)
    }
}
