import Foundation
import Testing
@testable import WidgetFeature

struct SessionActivityTextTests {
    private let nextSet = "Développé couché à la barre · série 2 · 70 kg × 5"

    @Test func fixedTexts() {
        #expect(SessionActivityText.restTitle == "Repos")
        #expect(SessionActivityText.nextSetTitle == "Série suivante")
        #expect(SessionActivityText.minus30Title == "−30 s")
        #expect(SessionActivityText.plus30Title == "+30 s")
        #expect(SessionActivityText.skipTitle == "Passer")
    }

    @Test func buttonsAreSpokenInFull() {
        #expect(SessionActivityText.minus30Label == "Retirer 30 secondes de repos")
        #expect(SessionActivityText.plus30Label == "Ajouter 30 secondes de repos")
        #expect(SessionActivityText.skipLabel == "Passer le repos")
    }

    @Test func restReadsRestAndNextSet() {
        let label = SessionActivityText.accessibilityLabel(title: "Push", isResting: true, nextSet: nextSet)
        #expect(label == "Repos, série suivante : Développé couché à la barre, série 2, 70 kilos, 5 répétitions")
    }

    @Test func restWithoutNextSet() {
        #expect(SessionActivityText.accessibilityLabel(title: "Push", isResting: true, nextSet: nil) == "Repos")
    }

    @Test func outsideRestReadsTitleAndNextSet() {
        let label = SessionActivityText.accessibilityLabel(title: "Push", isResting: false, nextSet: nextSet)
        #expect(label == "Séance Push, série suivante : Développé couché à la barre, série 2, 70 kilos, 5 répétitions")
    }

    @Test func outsideRestWithoutNextSetReadsTheTitle() {
        #expect(SessionActivityText.accessibilityLabel(title: "Push", isResting: false, nextSet: nil) == "Séance Push")
    }

    @Test func nextSetShapesTheBuilderProducesAreSpoken() {
        func spoken(_ values: String?) -> String {
            SessionActivityText.spokenNextSet(values.map { "Tractions · série 3 · \($0)" } ?? "Tractions · série 3")
        }
        #expect(spoken(nil) == "Tractions, série 3")
        #expect(spoken("62,5 kg × 5") == "Tractions, série 3, 62,5 kilos, 5 répétitions")
        #expect(spoken("1 kg × 1") == "Tractions, série 3, 1 kilo, 1 répétition")
        #expect(spoken("+10 kg × 8") == "Tractions, série 3, plus 10 kilos, 8 répétitions")
        #expect(spoken("−20 kg × 6") == "Tractions, série 3, moins 20 kilos, 6 répétitions")
        #expect(spoken("+10 kg") == "Tractions, série 3, plus 10 kilos")
        #expect(spoken("80 kg × 45 s") == "Tractions, série 3, 80 kilos, 45 secondes")
        #expect(spoken("90 s") == "Tractions, série 3, 1 minute 30")
        #expect(spoken("30 s") == "Tractions, série 3, 30 secondes")
        #expect(spoken("8 rép.") == "Tractions, série 3, 8 répétitions")
    }

    @Test func unknownNextSetShapesAreKeptAsTheyAre() {
        #expect(SessionActivityText.spokenNextSet("Pompes · série 1 · à fond") == "Pompes, série 1, à fond")
        #expect(SessionActivityText.spokenNextSet("Pompes") == "Pompes")
    }
}
