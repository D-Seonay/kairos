import Foundation
@testable import Pulse
import PulseDomain
import PulseServices
import Testing
import UserNotifications

/// Le rappel de check-in : son contenu, ses trois réponses rapides et son silence app ouverte.
@Suite struct CheckInNotificationTests {
    private static let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    /// Le matin du vendredi 20 novembre 2026, rappel à 7 h.
    private static func reminder() -> CheckInReminder {
        let day = paris.date(from: DateComponents(year: 2026, month: 11, day: 20)) ?? .distantPast
        return CheckInReminder(day: day, fireDate: day.addingTimeInterval(7 * 3600), title: "Comment tu te sens ?",
                               body: "Réponds d'un geste : Pulse estime ton score du jour.")
    }

    @Test func contentCarriesTheDayTheCategoryAndTheTodayLink() {
        let content = UserNotificationScheduler.checkInContent(Self.reminder())
        #expect(content.categoryIdentifier == UserNotificationScheduler.checkInCategory)
        #expect(NotificationRouter.link(from: content.userInfo) == .today)
        #expect(NotificationRouter.checkInDay(from: content.userInfo) == Self.reminder().day)
        #expect(UserNotificationScheduler.checkInIdentifier(Self.reminder(), calendar: Self.paris) == "fr.seonay.pulse.check-in.2026-11-20")
    }

    @Test func threeQuickAnswersRecordTheCheckInInTheBackground() throws {
        let category = try #require(UserNotificationScheduler.checkInCategories.first)
        #expect(category.actions.map(\.title) == ["En forme", "Moyen", "Fatigué"])
        #expect(category.actions.allSatisfy { !$0.options.contains(.foreground) })
        #expect(category.actions.map { UserNotificationScheduler.checkInAnswer(fromAction: $0.identifier) } == [.good, .average, .tired])
        #expect(UserNotificationScheduler.checkInAnswer(fromAction: UNNotificationDefaultActionIdentifier) == nil)
    }

    @Test func staysSilentWhileTheAppIsOpen() {
        #expect(NotificationRouter.presentationOptions(forIdentifier: "fr.seonay.pulse.check-in.2026-11-20").isEmpty)
        #expect(NotificationRouter.presentationOptions(forIdentifier: "fr.seonay.pulse.bedtime.2026-11-20") == [.banner, .sound])
    }
}
