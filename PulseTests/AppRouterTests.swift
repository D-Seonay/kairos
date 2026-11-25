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

    /// Un lien vers l'accueil referme l'écran Compléments et fait refermer l'écran « Pourquoi ».
    @Test func openingTodayPopsThePushedScreens() {
        let router = AppRouter()
        router.open(.supplements)
        #expect(router.isShowingSupplements)
        let version = router.todayRootVersion
        router.open(.today)
        #expect(!router.isShowingSupplements)
        #expect(router.todayRootVersion == version + 1)
    }

    @Test func planningLinkSelectsThePlanningTab() {
        let router = AppRouter()
        router.open(.planning)
        #expect(router.selectedTab == .planning)
        #expect(!router.pendingSessionStart)
    }

    /// Le contrôle « Séance du jour » ouvre l'accueil et laisse une demande de lancement aux onglets.
    @Test func startSessionLinkOpensTodayAndAsksForTheSession() {
        let router = AppRouter()
        router.selectedTab = .stats
        router.open(.startSession)
        #expect(router.selectedTab == .today)
        #expect(router.pendingSessionStart)
        #expect(router.sessionStartRequests == 1)
    }

    /// « Voir pourquoi » du raccourci Siri : l'accueil sans l'écran Compléments, sans changer la version qui refermerait
    /// l'écran « Pourquoi » demandé.
    @Test func whyLinkOpensTodayAndAsksForTheWhyScreen() {
        let router = AppRouter()
        router.open(.supplements)
        router.selectedTab = .stats
        let version = router.todayRootVersion
        router.open(.why)
        #expect(router.selectedTab == .today)
        #expect(!router.isShowingSupplements)
        #expect(router.todayRootVersion == version)
        #expect(router.pendingWhy)
        #expect(router.whyRequests == 1)
    }

    /// « Lancer une course » laisse une demande de course aux onglets, sans changer d'onglet.
    @Test func runLinkAsksForTheRun() {
        let router = AppRouter()
        router.selectedTab = .stats
        router.open(.run)
        #expect(router.selectedTab == .stats)
        #expect(router.pendingRunStart)
        #expect(router.runStartRequests == 1)
    }

    @Test func pendingRequestsAreDroppedTogether() {
        let router = AppRouter()
        router.open(.startSession)
        router.open(.why)
        router.open(.run)
        router.dropPendingRequests()
        #expect(!router.pendingSessionStart)
        #expect(!router.pendingWhy)
        #expect(!router.pendingRunStart)
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
