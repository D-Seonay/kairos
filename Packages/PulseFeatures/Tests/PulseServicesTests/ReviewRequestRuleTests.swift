import Foundation
import PulseServices
import Testing

/// La demande de note : à partir de la 5e séance terminée ou après un record, au plus une fois par version.
struct ReviewRequestRuleTests {
    private func ask(_ sessions: Int, record: Bool = false, version: String? = "1.0.4", last: String? = nil) -> Bool {
        ReviewRequestRule.shouldAsk(completedSessions: sessions, hasNewRecord: record, appVersion: version,
                                    lastRequestedVersion: last)
    }

    @Test func theFifthCompletedSessionAsks() {
        #expect(!ask(4))
        #expect(ask(5))
        #expect(ask(12))
    }

    @Test func aNewRecordAsksEarlier() {
        #expect(ask(1, record: true))
        #expect(!ask(1))
    }

    @Test func atMostOneRequestPerVersion() {
        #expect(!ask(8, record: true, last: "1.0.4"))
        #expect(ask(8, last: "1.0.3"))
    }

    @Test func anUnknownVersionNeverAsks() {
        #expect(!ask(8, record: true, version: nil))
        #expect(!ask(8, record: true, version: ""))
    }

    @Test func claimingRemembersTheVersion() {
        let store = InMemoryReviewRequestStore()
        let prompt = ReviewPrompt(store: store, appVersion: "1.0.4")
        #expect(!prompt.claim(completedSessions: 2, hasNewRecord: false))
        #expect(store.lastRequestedVersion == nil)
        #expect(prompt.claim(completedSessions: 5, hasNewRecord: false))
        #expect(store.lastRequestedVersion == "1.0.4")
        #expect(!prompt.claim(completedSessions: 6, hasNewRecord: true))
        // La version suivante peut redemander.
        #expect(ReviewPrompt(store: store, appVersion: "1.0.5").claim(completedSessions: 6, hasNewRecord: false))
    }

    @Test func theUserDefaultsStoreKeepsTheVersion() throws {
        let suite = "pulse.tests.review.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let store = UserDefaultsReviewRequestStore(suiteName: suite)
        #expect(store.lastRequestedVersion == nil)
        store.setLastRequestedVersion("1.0.4")
        #expect(UserDefaultsReviewRequestStore(suiteName: suite).lastRequestedVersion == "1.0.4")
    }

    @Test func theWriteReviewLinkPointsAtPulse() {
        #expect(ReviewPrompt.writeReviewURL?.absoluteString == "https://apps.apple.com/app/id6829265826?action=write-review")
    }
}
