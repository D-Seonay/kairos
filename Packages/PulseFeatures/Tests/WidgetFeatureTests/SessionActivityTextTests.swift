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
        #expect(label == "Repos, série suivante : \(nextSet)")
    }

    @Test func restWithoutNextSet() {
        #expect(SessionActivityText.accessibilityLabel(title: "Push", isResting: true, nextSet: nil) == "Repos")
    }

    @Test func outsideRestReadsTitleAndNextSet() {
        let label = SessionActivityText.accessibilityLabel(title: "Push", isResting: false, nextSet: nextSet)
        #expect(label == "Séance Push, série suivante : \(nextSet)")
    }

    @Test func outsideRestWithoutNextSetReadsTheTitle() {
        #expect(SessionActivityText.accessibilityLabel(title: "Push", isResting: false, nextSet: nil) == "Séance Push")
    }
}
