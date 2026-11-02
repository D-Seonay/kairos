@testable import PulseRecoveryEngine
import Testing

struct PlateRoundingTests {
    private let bar = WeightRounding.plates(barKg: 20, smallestPlateKg: 1.25)

    @Test func platesRoundUpToAPair() {
        #expect(PlateRounding.nextLoad(after: 60, increment: 1.25, rounding: bar) == 62.5)
        #expect(PlateRounding.nextLoad(after: 27, increment: 3.5, rounding: .increment) == 30.5)
    }

    @Test func aLoadAlreadyReachableByPairsIsKept() {
        #expect(PlateRounding.nextLoad(after: 60, increment: 2.5, rounding: bar) == 62.5)
        #expect(PlateRounding.nextLoad(after: 70, increment: 5, rounding: bar) == 75)
    }

    @Test func aTargetBelowTheBarGivesTheBar() {
        #expect(PlateRounding.nextLoad(after: 10, increment: 2.5, rounding: bar) == 20)
    }

    @Test func aLargerIncrementJumpsSeveralPairs() {
        #expect(PlateRounding.nextLoad(after: 60, increment: 3, rounding: bar) == 65)
    }

    @Test func aNonPositivePlateFallsBackToTheIncrement() {
        #expect(PlateRounding.nextLoad(after: 60, increment: 2.5, rounding: .plates(barKg: 20, smallestPlateKg: 0)) == 62.5)
    }
}
