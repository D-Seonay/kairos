import Foundation
import os
import PulseDomain
import PulseServices
import UserNotifications

/// Le délégué du centre de notifications : une notification touchée ouvre l'onglet de son lien ; l'app ouverte affiche les autres,
/// mais tait le score du matin, déjà à l'écran (le passage au premier plan le retire du centre de notifications), et la fin du
/// repos, que la vibration longue de l'écran de séance annonce déjà (spec M4 §15.2), et le rappel de check-in, que la bannière de
/// l'accueil demande déjà. L'action « Pris » d'un rappel de complément enregistre la prise sans ouvrir l'app (spec M5 §7), comme
/// une réponse rapide du rappel de check-in enregistre le check-in.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    /// La clé du lien dans `userInfo`, posée par `UserNotificationScheduler`.
    static let linkKey = "link"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "fr.seonay.pulse", category: "notifications")

    private let router: AppRouter
    private let supplements: SupplementService
    private let checkIns: CheckInReminderService?

    init(router: AppRouter, supplements: SupplementService, checkIns: CheckInReminderService? = nil) {
        self.router = router
        self.supplements = supplements
        self.checkIns = checkIns
    }

    /// Le jour d'un rappel de check-in ; `nil` pour une autre notification.
    static func checkInDay(from userInfo: [AnyHashable: Any]) -> Date? {
        (userInfo[UserNotificationScheduler.checkInDayKey] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
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
            _ = try? await supplements.take(supplementID: intake.id, day: intake.day)
            await router.supplementsChanged()
            return
        }
        if let answer = UserNotificationScheduler.checkInAnswer(fromAction: response.actionIdentifier),
           let day = Self.checkInDay(from: userInfo) {
            // Une réponse d'arrière-plan ne peut pas ouvrir l'app : un check-in refusé (la notification de la veille touchée après
            // minuit, un score mesuré déjà là) n'est signalé nulle part, et l'accueil redemande le check-in du jour à l'ouverture.
            if await checkIns?.answer(answer, day: day) == false {
                Self.logger.notice("Réponse rapide de check-in non enregistrée (autre jour ou check-in refusé)")
            }
            return
        }
        await router.open(Self.link(from: userInfo))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Self.presentationOptions(forIdentifier: notification.request.identifier)
    }

    /// Rien pour le score du matin, la fin du repos et le rappel de check-in, une bannière et un son pour le reste.
    static func presentationOptions(forIdentifier identifier: String) -> UNNotificationPresentationOptions {
        silentInForeground.contains(identifier) || identifier.hasPrefix(UserNotificationScheduler.checkInPrefix)
            ? [] : [.banner, .sound]
    }

    private static let silentInForeground: Set<String> = [
        UserNotificationScheduler.morningScoreIdentifier, UserNotificationScheduler.restTimerIdentifier
    ]
}
