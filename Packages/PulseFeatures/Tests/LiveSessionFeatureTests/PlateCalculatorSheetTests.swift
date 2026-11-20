@testable import LiveSessionFeature
import PulseRecoveryEngine
import Testing

struct PlateCalculatorSheetTests {
    @Test func perSideTextListsThePlatesOrSaysTheBarIsAlone() {
        #expect(PlateCalculatorSheet.perSideText(PlateLoading(totalKg: 102.5, perSide: [25, 15, 1.25]))
                == "Par côté : 25 + 15 + 1,25 kg")
        #expect(PlateCalculatorSheet.perSideText(PlateLoading(totalKg: 20, perSide: [])) == "Barre seule")
    }
}
