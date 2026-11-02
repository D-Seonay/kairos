import Foundation
import PulseServices
import Testing

struct DayActivityLogTests {
    private let suite = "fr.seonay.pulse.tests.day-activity-log"
    private let opened = TestClock.date("2026-11-02T07:00")
    private let notified = TestClock.date("2026-11-02T00:00")

    private func clearSuite() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    @Test func userDefaultsLogRoundTrips() {
        clearSuite()
        defer { clearSuite() }
        let log = UserDefaultsDayActivityLog(suiteName: suite)
        #expect(log.lastOpenedAt() == nil)
        #expect(log.lastNotifiedDay() == nil)

        log.markOpened(at: opened)
        log.markNotified(day: notified)
        #expect(log.lastOpenedAt() == opened)
        #expect(log.lastNotifiedDay() == notified)
        // Une autre instance sur la même suite relit ce qui a été écrit.
        #expect(UserDefaultsDayActivityLog(suiteName: suite).lastOpenedAt() == opened)
    }

    @Test func userDefaultsLogKeepsItsKeysUnderThePulsePrefix() {
        clearSuite()
        defer { clearSuite() }
        let log = UserDefaultsDayActivityLog(suiteName: suite)
        log.markOpened(at: opened)
        log.markNotified(day: notified)

        let defaults = UserDefaults(suiteName: suite)
        #expect(defaults?.object(forKey: "pulse.lastOpenedAt") as? Date == opened)
        #expect(defaults?.object(forKey: "pulse.lastNotifiedDay") as? Date == notified)
        // La suppression totale vide le domaine : les deux clés partent avec lui.
        clearSuite()
        #expect(log.lastOpenedAt() == nil)
        #expect(log.lastNotifiedDay() == nil)
    }

    @Test func inMemoryLogRoundTrips() {
        let log = InMemoryDayActivityLog()
        #expect(log.lastOpenedAt() == nil)
        #expect(log.lastNotifiedDay() == nil)

        log.markOpened(at: opened)
        log.markNotified(day: notified)
        #expect(log.lastOpenedAt() == opened)
        #expect(log.lastNotifiedDay() == notified)
    }
}
