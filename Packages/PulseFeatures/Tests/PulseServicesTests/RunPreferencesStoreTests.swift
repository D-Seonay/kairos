import Foundation
import Testing

@testable import PulseServices

struct RunPreferencesStoreTests {
    @Test func announcementsAreOnUntilTurnedOff() throws {
        let suiteName = "pulse.tests.runPreferences.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsRunPreferencesStore(suiteName: suiteName)
        #expect(store.announcesKilometres)
        store.setAnnouncesKilometres(false)
        #expect(!UserDefaultsRunPreferencesStore(suiteName: suiteName).announcesKilometres)
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.object(forKey: "pulse.run.announcesKilometres") as? Bool == false)
    }

    @Test func inMemoryStoreDefaultsToOn() {
        let store = InMemoryRunPreferencesStore()
        #expect(store.announcesKilometres)
        store.setAnnouncesKilometres(false)
        #expect(!store.announcesKilometres)
    }
}
