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

    // MARK: Rappel de coucher

    private static let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    /// Le soir du vendredi 20 novembre 2026, rappel à 22 h 15.
    private static func bedtimeReminder() -> BedtimeReminder {
        let evening = paris.date(from: DateComponents(year: 2026, month: 11, day: 20)) ?? .distantPast
        return BedtimeReminder(evening: evening, fireDate: evening.addingTimeInterval(22 * 3600 + 15 * 60),
                               title: "Couche-toi vers 22:45", body: "Vise 8 h de sommeil.")
    }

    @Test func bedtimeReminderLinksToTheNight() {
        let content = UserNotificationScheduler.bedtimeContent(Self.bedtimeReminder())
        #expect(NotificationRouter.link(from: content.userInfo) == .night)
        #expect(content.title == "Couche-toi vers 22:45")
        #expect(content.body == "Vise 8 h de sommeil.")
        #expect(content.categoryIdentifier.isEmpty)
    }

    @Test func bedtimeIdentifierNamesTheEvening() {
        #expect(UserNotificationScheduler.bedtimeIdentifier(Self.bedtimeReminder(), calendar: Self.paris)
            == "fr.seonay.pulse.bedtime.2026-11-20")
        #expect(UserNotificationScheduler.bedtimePrefix == "fr.seonay.pulse.bedtime.")
    }

    @Test func bedtimeReminderShowsABannerInForeground() {
        let identifier = UserNotificationScheduler.bedtimeIdentifier(Self.bedtimeReminder(), calendar: Self.paris)
        #expect(NotificationRouter.presentationOptions(forIdentifier: identifier) == [.banner, .sound])
    }

    @Test func restEndFiresAtItsEndAndNeverInThePast() {
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(90), now: now) == 90)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(0.2), now: now) == 1)
        #expect(UserNotificationScheduler.restEndDelay(until: now.addingTimeInterval(-30), now: now) == 1)
    }
}
