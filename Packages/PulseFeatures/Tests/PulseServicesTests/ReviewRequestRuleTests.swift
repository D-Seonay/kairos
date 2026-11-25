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

    @Test func claimingRemembersTheVersion() async {
        let store = InMemoryReviewRequestStore()
        let prompt = ReviewPrompt(store: store, appVersion: "1.0.4")
        #expect(await !prompt.claim(hasNewRecord: false) { 2 })
        #expect(store.lastRequestedVersion == nil)
        #expect(await prompt.claim(hasNewRecord: false) { 5 })
        #expect(store.lastRequestedVersion == "1.0.4")
        #expect(await !prompt.claim(hasNewRecord: true) { 6 })
        // La version suivante peut redemander.
        #expect(await ReviewPrompt(store: store, appVersion: "1.0.5").claim(hasNewRecord: false) { 6 })
    }

    @Test func sessionsAreCountedOnlyWhenNeeded() async {
        let counted = Counter()
        let served = ReviewPrompt(store: InMemoryReviewRequestStore(lastRequestedVersion: "1.0.4"), appVersion: "1.0.4")
        #expect(await !served.claim(hasNewRecord: false) { await counted.next() })
        let fresh = ReviewPrompt(store: InMemoryReviewRequestStore(), appVersion: "1.0.4")
        #expect(await fresh.claim(hasNewRecord: true) { await counted.next() })
        #expect(await counted.value == 0)
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

/// Compte les appels du comptage des séances.
private actor Counter {
    private(set) var value = 0

    func next() -> Int {
        value += 1
        return 5
    }
}
