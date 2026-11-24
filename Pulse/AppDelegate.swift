import HealthKit
import HealthKitUI
import PulseServices
import UIKit
import UserNotifications

/// Assemble l'app au lancement, avant toute scène : Apple Santé peut la réveiller en arrière-plan, sans interface,
/// pour calculer le score du matin et l'annoncer.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let dependencies = AppDependencies.live()
    let router = AppRouter()
    /// Les boutons de la Live Activity, branchés avant toute scène : un bouton peut réveiller l'app en arrière-plan.
    private(set) lazy var sessionIntents = SessionIntentWiring(service: dependencies.liveSession,
                                                               runService: dependencies.run.service)
    /// Le centre de notifications ne retient pas son délégué : c'est l'app qui le garde.
    private var notificationRouter: NotificationRouter?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let notificationRouter = NotificationRouter(router: router, supplements: dependencies.supplementService)
        UNUserNotificationCenter.current().delegate = notificationRouter
        UNUserNotificationCenter.current().setNotificationCategories(UserNotificationScheduler.supplementCategories)
        self.notificationRouter = notificationRouter
        sessionIntents.install()
        let refresher = dependencies.refresher
        dependencies.backgroundDelivery?.start {
            // L'app ouverte lit elle-même au premier plan : une lecture d'arrière-plan l'annoncerait pendant qu'on la regarde.
            guard await Self.isInBackground() else { return }
            _ = await refresher.refresh(origin: .background)
        }
        return true
    }

    /// Après un crash pendant une course, le système relance l'app pour qu'elle reprenne la séance HealthKit encore active : la
    /// séance de course la reprend, par le même chemin que l'offre de reprise de la racine, qui la rattache ensuite au brouillon
    /// (spec V2a §5.4). La scène reste celle de SwiftUI.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.shouldHandleActiveWorkoutRecovery, let runHealthSession = dependencies.run.healthSession {
            Task { _ = await runHealthSession.recoverActiveSession() }
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Une livraison reçue iPhone verrouillé n'a rien pu lire : la lecture est refaite au déverrouillage.
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        guard Self.isInBackground() else { return }
        let refresher = dependencies.refresher
        Task { _ = await refresher.refresh(origin: .background) }
    }

    private static func isInBackground() -> Bool {
        UIApplication.shared.applicationState == .background
    }
}
