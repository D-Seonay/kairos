import PulseDomain
import UserNotifications

/// Demande l'autorisation des notifications au système : alerte, son et pastille. Une erreur vaut un refus.
struct UserNotificationAuthorizer: NotificationAuthorizing {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Vrai quand les notifications de Pulse sont refusées dans les réglages d'iOS (Paramètres → Notifications).
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
