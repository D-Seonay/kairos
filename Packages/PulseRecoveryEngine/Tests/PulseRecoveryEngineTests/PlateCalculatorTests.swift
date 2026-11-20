@testable import PulseRecoveryEngine
import Testing

struct PlateCalculatorTests {
    private let plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    @Test func anExactLoadUsesTheFewestPlates() {
        let result = PlateCalculator.load(targetKg: 100, barKg: 20, availablePlatesKg: plates)
        #expect(result == .exact(PlateLoading(totalKg: 100, perSide: [25, 15])))
    }

    @Test func fewestPlatesIsNotAlwaysGreedy() {
        // 30 kg par côté avec 25, 15 et 10 : le glouton prend 25 puis bloque ; deux 15 font l'affaire.
        let result = PlateCalculator.load(targetKg: 80, barKg: 20, availablePlatesKg: [25, 15, 10])
        #expect(result == .exact(PlateLoading(totalKg: 80, perSide: [15, 15])))
    }

    @Test func theBarAloneHasNoPlate() {
        #expect(PlateCalculator.load(targetKg: 20, barKg: 20, availablePlatesKg: plates)
                == .exact(PlateLoading(totalKg: 20, perSide: [])))
    }

    @Test func anImpossibleLoadGivesTheTwoClosest() {
        let result = PlateCalculator.load(targetKg: 101, barKg: 20, availablePlatesKg: plates)
        #expect(result == .approximate(lower: PlateLoading(totalKg: 100, perSide: [25, 15]),
                                       upper: PlateLoading(totalKg: 102.5, perSide: [25, 15, 1.25])))
    }

    @Test func belowTheBarOnlyTheBarIsOffered() {
        #expect(PlateCalculator.load(targetKg: 15, barKg: 20, availablePlatesKg: plates)
                == .approximate(lower: nil, upper: PlateLoading(totalKg: 20, perSide: [])))
    }

    @Test func plateOrderAndJunkValuesDoNotMatter() {
        let result = PlateCalculator.load(targetKg: 60, barKg: 20, availablePlatesKg: [1.25, 0, -5, 20, 20])
        #expect(result == .exact(PlateLoading(totalKg: 60, perSide: [20])))
    }

    @Test func withoutPlatesOnlyTheBarIsFeasible() {
        #expect(PlateCalculator.load(targetKg: 60, barKg: 20, availablePlatesKg: [])
                == .approximate(lower: PlateLoading(totalKg: 20, perSide: []), upper: nil))
    }
}
