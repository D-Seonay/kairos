import PulseDomain
import UserNotifications

/// La notification du score du matin, envoyée tout de suite, et la suppression des notifications de Pulse.
struct UserNotificationScheduler: NotificationScheduling, NotificationCanceling {
    static let morningScoreIdentifier = "fr.seonay.pulse.morning-score"

    /// Remplace la notification précédente du même identifiant. Un refus du système laisse simplement l'app sans notification.
    func scheduleMorningScore(_ message: MorningScoreMessage) async {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.userInfo = [NotificationRouter.linkKey: AppLink.today.rawValue]
        let request = UNNotificationRequest(identifier: Self.morningScoreIdentifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelMorningScore() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningScoreIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.morningScoreIdentifier])
    }

    func cancelAllScheduled() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
