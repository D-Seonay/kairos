import PulseServices
import UIKit
import UserNotifications

/// Assemble l'app au lancement, avant toute scène : Apple Santé peut la réveiller en arrière-plan, sans interface,
/// pour calculer le score du matin et l'annoncer.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let dependencies = AppDependencies.live()
    let router = AppRouter()
    /// Le centre de notifications ne retient pas son délégué : c'est l'app qui le garde.
    private var notificationRouter: NotificationRouter?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let notificationRouter = NotificationRouter(router: router)
        UNUserNotificationCenter.current().delegate = notificationRouter
        self.notificationRouter = notificationRouter
        let refresher = dependencies.refresher
        dependencies.backgroundDelivery?.start {
            // L'app ouverte lit elle-même au premier plan : une lecture d'arrière-plan l'annoncerait pendant qu'on la regarde.
            guard await Self.isInBackground() else { return }
            _ = await refresher.refresh(origin: .background)
        }
        return true
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
