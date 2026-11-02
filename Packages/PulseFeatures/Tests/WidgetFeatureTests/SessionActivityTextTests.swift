import Foundation
import Testing
@testable import WidgetFeature

struct SessionActivityTextTests {
    private let now = WidgetClock.date("2026-11-02T18:00")
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

    @Test func restReadsTimeLeftAndNextSet() {
        let label = SessionActivityText.accessibilityLabel(
            title: "Push", restEndsAt: now.addingTimeInterval(112), nextSet: nextSet, now: now)
        #expect(label == "Repos, 1 minute et 52 secondes restantes, série suivante : \(nextSet)")
    }

    @Test func restUnderAMinuteReadsSeconds() {
        let label = SessionActivityText.accessibilityLabel(
            title: "Push", restEndsAt: now.addingTimeInterval(45), nextSet: nil, now: now)
        #expect(label == "Repos, 45 secondes restantes")
    }

    @Test func outsideRestReadsTitleAndNextSet() {
        let label = SessionActivityText.accessibilityLabel(title: "Push", restEndsAt: nil, nextSet: nextSet, now: now)
        #expect(label == "Séance Push, série suivante : \(nextSet)")
    }

    @Test func finishedRestIsOutsideRest() {
        let label = SessionActivityText.accessibilityLabel(
            title: "Push", restEndsAt: now.addingTimeInterval(-5), nextSet: nil, now: now)
        #expect(label == "Séance Push")
    }
}
