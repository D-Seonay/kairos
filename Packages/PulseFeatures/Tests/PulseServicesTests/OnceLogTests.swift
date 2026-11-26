import Foundation
import Testing

@testable import PulseServices

struct OnceLogTests {
    @Test func anEventIsRememberedAcrossLaunches() throws {
        let suiteName = "pulse.tests.once.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let log = UserDefaultsOnceLog(suiteName: suiteName)
        #expect(!log.hasHappened(.notificationsDisabledNotice))
        log.record(.notificationsDisabledNotice)
        // Une autre instance sur la même suite : ce que l'app retrouve au lancement suivant.
        #expect(UserDefaultsOnceLog(suiteName: suiteName).hasHappened(.notificationsDisabledNotice))
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        #expect(defaults.object(forKey: "pulse.once.notificationsDisabledNotice") as? Bool == true)
    }

    @Test func inMemoryLogStartsEmpty() {
        let log = InMemoryOnceLog()
        #expect(!log.hasHappened(.notificationsDisabledNotice))
        log.record(.notificationsDisabledNotice)
        #expect(log.hasHappened(.notificationsDisabledNotice))
    }
}
