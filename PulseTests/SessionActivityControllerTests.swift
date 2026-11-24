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
            restEndsAt: Self.start.addingTimeInterval(690), nextSet: "Développé couché à la barre · série 2 · 70 kg × 5",
            doneSets: 4, plannedSets: 15)
        #expect(SessionActivityController.contentState(for: state) == PulseSessionAttributes.ContentState(
            title: "Push", startedAt: Self.start, restStartedAt: Self.start.addingTimeInterval(600),
            restEndsAt: Self.start.addingTimeInterval(690), nextSet: "Développé couché à la barre · série 2 · 70 kg × 5",
            doneSets: 4, plannedSets: 15))
    }

    @Test func stateWithoutRestLeavesTheRestEmpty() {
        let state = SessionActivityState(sessionID: UUID(), title: "Séance libre", startedAt: Self.start)
        let content = SessionActivityController.contentState(for: state)
        #expect(content.title == "Séance libre" && content.startedAt == Self.start)
        #expect(content.restStartedAt == nil && content.restEndsAt == nil && content.nextSet == nil)
        #expect(content.doneSets == 0 && content.plannedSets == 0)
    }

    /// Une activité lancée avant le compte des séries n'a pas ces clés : elle se relit, sans progression.
    @Test func contentWithoutTheSetCountsStillDecodes() throws {
        let json = Data(#"{"title":"Push","startedAt":0}"#.utf8)
        let content = try JSONDecoder().decode(PulseSessionAttributes.ContentState.self, from: json)
        #expect(content.title == "Push" && content.doneSets == nil && content.plannedSets == nil)
    }

    @Test func attributesCarryTheSession() {
        let id = UUID()
        let state = SessionActivityState(sessionID: id, title: "Push", startedAt: Self.start)
        #expect(SessionActivityController.attributes(for: state).sessionID == id)
    }
}
