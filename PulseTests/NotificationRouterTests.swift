import Foundation
@testable import Pulse
import PulseDomain
import Testing
import UserNotifications

@Suite struct NotificationRouterTests {
    @Test func restEndStaysSilentWhileTheAppIsOpen() {
        #expect(UserNotificationScheduler.restTimerIdentifier == "fr.seonay.pulse.rest-timer")
        #expect(NotificationRouter.presentationOptions(forIdentifier: UserNotificationScheduler.restTimerIdentifier).isEmpty)
    }

    @Test func restEndIsTimeSensitive() {
        let content = UserNotificationScheduler.restEndContent(RestEndMessage(title: "Repos terminé",
                                                                              body: "Développé couché, série 3 : 70 kg × 5"))
        #expect(content.interruptionLevel == .timeSensitive)
        #expect(content.title == "Repos terminé")
        #expect(content.body == "Développé couché, série 3 : 70 kg × 5")
    }

    @Test func restEndFiresAtItsEndAndNeverInThePast() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(90), now: now) == 90)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(0.2), now: now) == 1)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(-30), now: now) == 1)
    }
}
