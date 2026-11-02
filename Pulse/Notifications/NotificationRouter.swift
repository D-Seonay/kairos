import Foundation
import PulseDomain
import UserNotifications

/// Le délégué du centre de notifications : une notification touchée ouvre l'onglet de son lien ; l'app ouverte affiche les autres,
/// mais tait le score du matin, déjà à l'écran (le passage au premier plan le retire du centre de notifications).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    /// La clé du lien dans `userInfo`, posée par `UserNotificationScheduler`.
    static let linkKey = "link"

    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    /// Le lien de la notification ; « Aujourd'hui » quand il manque ou est inconnu.
    static func link(from userInfo: [AnyHashable: Any]) -> AppLink {
        (userInfo[linkKey] as? String).flatMap(AppLink.init(rawValue:)) ?? .today
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let link = Self.link(from: response.notification.request.content.userInfo)
        await router.open(link)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Self.presentationOptions(forIdentifier: notification.request.identifier)
    }

    /// Rien pour le score du matin, une bannière et un son pour le reste.
    static func presentationOptions(forIdentifier identifier: String) -> UNNotificationPresentationOptions {
        identifier == UserNotificationScheduler.morningScoreIdentifier ? [] : [.banner, .sound]
    }
}
