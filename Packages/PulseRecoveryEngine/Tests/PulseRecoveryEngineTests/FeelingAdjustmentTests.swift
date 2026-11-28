import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct FeelingAdjustmentTests {
    @Test func aTenthOfTheGapIsApplied() {
        let result = FeelingAdjustment.apply(measured: 70, checkInScore: 90)
        #expect(abs(result.points - 2) < 1e-9)
        #expect(abs(result.score - 72) < 1e-9)
        #expect(result.measured == 70)
    }

    @Test func theModifierIsCappedAtFivePoints() {
        #expect(FeelingAdjustment.apply(measured: 70, checkInScore: 0).points == -5)
        #expect(FeelingAdjustment.apply(measured: 10, checkInScore: 100).points <= 5)
    }

    @Test func feelingWorseCanLowerTheCategory() {
        let result = FeelingAdjustment.apply(measured: 66, checkInScore: 0)
        #expect(result.score == 61)
        #expect(RecoveryCategory(score: result.score) == .moderateFatigue)
    }

    /// Un jour rouge ne passe jamais au vert : un meilleur ressenti s'arrête au haut de la catégorie mesurée.
    @Test(arguments: [(37.0, 39.0), (62.0, 64.0), (89.2, 89.2)])
    func feelingBetterNeverRaisesTheCategory(measured: Double, ceiling: Double) {
        let result = FeelingAdjustment.apply(measured: measured, checkInScore: 100)
        #expect(result.score == ceiling)
        #expect(RecoveryCategory(score: result.score) == RecoveryCategory(score: measured))
    }

    /// Le score s'affiche arrondi : 61 + 3,9 = 64,9 resterait orange mais s'afficherait « 65 ». Il s'arrête au plus haut score
    /// entier de la catégorie, comme à 39,5 et 89,5.
    @Test(arguments: [(36.0, 71.0, 39.0), (61.0, 100.0, 64.0), (88.5, 98.5, 89.0)])
    func feelingBetterNeverRoundsIntoTheNextCategory(measured: Double, checkIn: Double, ceiling: Double) {
        let result = FeelingAdjustment.apply(measured: measured, checkInScore: checkIn)
        #expect(result.score == ceiling)
        #expect(RecoveryCategory(score: result.score.rounded()) == RecoveryCategory(score: measured))
    }

    @Test func aBetterFeelingThatRoundsInsideTheCategoryIsKept() {
        let result = FeelingAdjustment.apply(measured: 61, checkInScore: 95)
        #expect(abs(result.score - 64.4) < 1e-9)
    }

    @Test func aScoreAlreadyAtTheTopOfItsCategoryIsNotLowered() {
        let result = FeelingAdjustment.apply(measured: 89.6, checkInScore: 100)
        #expect(result.points == 0)
    }

    @Test func theScoreStaysWithinZeroAndHundred() {
        #expect(FeelingAdjustment.apply(measured: 98, checkInScore: 100).score <= 100)
        #expect(FeelingAdjustment.apply(measured: 2, checkInScore: 0).score >= 0)
    }
}
