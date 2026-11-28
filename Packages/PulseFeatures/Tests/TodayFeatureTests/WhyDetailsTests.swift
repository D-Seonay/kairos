import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing
@testable import TodayFeature

/// Ce que l'écran « Pourquoi » dit du calcul (#115, #117, #118) et le ressenti du matin, à part de la formule (#119).
struct WhyDetailsTests {
    private let insight = RecoveryInsight(hrvBaselineNights: 14, hrvSetAsideNights: 0, restingHeartRateSource: .overnightLowest,
                                          sleepDebtMinutes: 220)

    @Test func linesSayTheBaselineTheHeartRateSourceAndTheDebt() {
        #expect(WhyDetails.lines(recovery: WhyFixture.recovery(), insight: insight) == [
            "Ligne de base VFC : médiane de tes 14 nuits d'avant.",
            "FC au repos : la plus basse de ta nuit, comparée à celle de tes 7 nuits d'avant.",
            "Dette de sommeil : 3 h 40 sur 7 nuits, qui compte pour 30 % du sommeil."
        ])
    }

    @Test func setAsideNightsAreCounted() {
        var thin = insight
        thin.hrvBaselineNights = 11
        thin.hrvSetAsideNights = 3
        #expect(WhyDetails.baseline(thin) == "Ligne de base VFC : médiane de 11 nuits ; 3 nuits écartées, trop peu mesurées.")
        thin.hrvSetAsideNights = 1
        #expect(WhyDetails.baseline(thin) == "Ligne de base VFC : médiane de 11 nuits ; 1 nuit écartée, trop peu mesurée.")
    }

    @Test func theAppleFallbackIsNamed() {
        #expect(WhyDetails.restingHeartRate(.appleNearWake)
            == "FC au repos : la valeur d'Apple Santé la plus proche de ton réveil, comparée à celle de tes 7 nuits d'avant.")
    }

    @Test func noDebtIsSaid() {
        #expect(WhyDetails.sleepDebt(minutes: 0) == "La dette de sommeil (30 % du sommeil) est nulle sur 7 nuits.")
    }

    /// Mesuré 58, ressenti à 53,75 : −0,4 point, arrondi à 0. Ni « de plus » ni « de moins ».
    @Test func aFeelingThatRoundsToZeroSaysNoPoint() {
        let checkIn = WhyFixture.checkIn(sleep: 3, pain: 2, motivation: 1, score: 53.75)
        #expect(WhyDetails.feeling(recovery: WhyFixture.recovery(), checkIn: checkIn)
            == "Ressenti du matin : aucun point, le score reste à 58 (± 5 au plus).")
    }

    @Test func missingFactorsAndEstimatedScoresSayNothing() {
        let withoutHRV = WhyFixture.recovery { $0.missingFactors = [.hrv]; $0.hrvScore = nil }
        #expect(WhyDetails.lines(recovery: withoutHRV, insight: insight).count == 2)
        #expect(WhyDetails.lines(recovery: WhyFixture.estimated(score: 60), insight: insight).isEmpty)
        #expect(WhyDetails.lines(recovery: WhyFixture.recovery(), insight: nil).isEmpty)
    }

    /// Mesuré 58, ressenti au plus bas : la formule reste celle de la mesure, le ressenti s'affiche à part.
    @Test func theFeelingIsShownApartFromTheFormula() throws {
        let checkIn = WhyFixture.checkIn(sleep: 0, pain: 0, motivation: 0, score: 0)
        let recovery = WhyFixture.recovery(score: 53)
        let content = try WhyFixture.content(recovery, checkIn: checkIn)
        #expect(content.formula == "Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58")
        #expect(content.feeling == "Ressenti du matin : −5 → 53 (± 5 au plus).")
    }

    @Test func noCheckInNoFeeling() throws {
        #expect(try WhyFixture.content(WhyFixture.recovery()).feeling == nil)
    }
}
