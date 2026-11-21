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

    /// L'autorisation des notifications de Pulse dans les réglages d'iOS (Paramètres → Notifications) ; provisoire et
    /// éphémère valent une autorisation.
    static func status() async -> NotificationAuthorizationStatus {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }
}
