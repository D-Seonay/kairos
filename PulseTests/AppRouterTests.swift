@testable import Pulse
import PulseDomain
import Testing
import UserNotifications

@MainActor
@Suite struct AppRouterTests {
    @Test func openingTodaySelectsTheTab() {
        let router = AppRouter()
        router.selectedTab = .profile
        router.open(.today)
        #expect(router.selectedTab == .today)
    }

    @Test func notificationLinkDefaultsToToday() {
        #expect(NotificationRouter.link(from: ["link": "today"]) == .today)
        #expect(NotificationRouter.link(from: [:]) == .today)
    }

    @Test func morningNotificationStaysSilentWhileTheAppIsOpen() {
        #expect(NotificationRouter.presentationOptions(forIdentifier: UserNotificationScheduler.morningScoreIdentifier).isEmpty)
        #expect(NotificationRouter.presentationOptions(forIdentifier: "other") == [.banner, .sound])
    }
}
