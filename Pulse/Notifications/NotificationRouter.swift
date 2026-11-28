import Foundation
import PulseDomain
import PulseServices
import UserNotifications

/// Le délégué du centre de notifications : une notification touchée ouvre l'onglet de son lien ; l'app ouverte affiche les autres,
/// mais tait le score du matin, déjà à l'écran (le passage au premier plan le retire du centre de notifications), et la fin du
/// repos, que la vibration longue de l'écran de séance annonce déjà (spec M4 §15.2). L'action « Pris » d'un rappel de complément
/// enregistre la prise sans ouvrir l'app (spec M5 §7).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    /// La clé du lien dans `userInfo`, posée par `UserNotificationScheduler`.
    static let linkKey = "link"

    private let router: AppRouter
    private let supplements: SupplementService

    init(router: AppRouter, supplements: SupplementService) {
        self.router = router
        self.supplements = supplements
    }

    /// Le complément et le jour d'un rappel ; `nil` pour une autre notification.
    static func supplementIntake(from userInfo: [AnyHashable: Any]) -> (id: UUID, day: Date)? {
        guard let id = (userInfo[UserNotificationScheduler.supplementIDKey] as? String).flatMap(UUID.init(uuidString:)),
              let day = userInfo[UserNotificationScheduler.supplementDayKey] as? TimeInterval else { return nil }
        return (id, Date(timeIntervalSince1970: day))
    }

    /// Le lien de la notification ; « Aujourd'hui » quand il manque ou est inconnu.
    static func link(from userInfo: [AnyHashable: Any]) -> AppLink {
        (userInfo[linkKey] as? String).flatMap(AppLink.init(rawValue:)) ?? .today
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if response.actionIdentifier == UserNotificationScheduler.supplementTakeAction,
           let intake = Self.supplementIntake(from: userInfo) {
            // Une prise déjà cochée, ou un complément supprimé entre-temps, ne compte pas : rien d'autre à faire.
            do {
                _ = try await supplements.take(supplementID: intake.id, day: intake.day)
            } catch {
                logger.failure("Prise de complément depuis la notification non enregistrée", error)
            }
            await router.supplementsChanged()
            return
        }
        await router.open(Self.link(from: userInfo))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Self.presentationOptions(forIdentifier: notification.request.identifier)
    }

    /// Rien pour le score du matin ni pour la fin du repos, une bannière et un son pour le reste.
    static func presentationOptions(forIdentifier identifier: String) -> UNNotificationPresentationOptions {
        silentInForeground.contains(identifier) ? [] : [.banner, .sound]
    }

    private static let silentInForeground: Set<String> = [
        UserNotificationScheduler.morningScoreIdentifier, UserNotificationScheduler.restTimerIdentifier
    ]
}
