import Foundation
@testable import Pulse
import PulseDomain
import PulseLiveActivity
import Testing

@Suite struct SessionActivityControllerTests {
    private static let start = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func restingStateBecomesTheActivityContent() {
        let state = SessionActivityState(
            sessionID: UUID(), title: "Push", startedAt: Self.start, restStartedAt: Self.start.addingTimeInterval(600),
            restEndsAt: Self.start.addingTimeInterval(690), nextSet: "Développé couché à la barre · série 2 · 70 kg × 5")
        #expect(SessionActivityController.contentState(for: state) == PulseSessionAttributes.ContentState(
            title: "Push", startedAt: Self.start, restStartedAt: Self.start.addingTimeInterval(600),
            restEndsAt: Self.start.addingTimeInterval(690), nextSet: "Développé couché à la barre · série 2 · 70 kg × 5"))
    }

    @Test func stateWithoutRestLeavesTheRestEmpty() {
        let state = SessionActivityState(sessionID: UUID(), title: "Séance libre", startedAt: Self.start)
        let content = SessionActivityController.contentState(for: state)
        #expect(content.title == "Séance libre" && content.startedAt == Self.start)
        #expect(content.restStartedAt == nil && content.restEndsAt == nil && content.nextSet == nil)
    }

    @Test func attributesCarryTheSession() {
        let id = UUID()
        let state = SessionActivityState(sessionID: id, title: "Push", startedAt: Self.start)
        #expect(SessionActivityController.attributes(for: state).sessionID == id)
    }
}
