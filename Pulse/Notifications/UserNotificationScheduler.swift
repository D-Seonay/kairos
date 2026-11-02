import Foundation
import PulseDomain
import UserNotifications

/// La notification du score du matin, envoyée tout de suite, celle de la fin du repos, et la suppression des notifications de Pulse.
struct UserNotificationScheduler: NotificationScheduling, NotificationCanceling, RestTimerNotifying {
    static let morningScoreIdentifier = "fr.seonay.pulse.morning-score"
    /// Un seul identifiant : chaque nouveau repos remplace la notification du précédent.
    static let restTimerIdentifier = "fr.seonay.pulse.rest-timer"

    let now: @Sendable () -> Date

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

    /// Remplace la notification de fin de repos, et retire celle d'un repos précédent restée dans le centre de notifications.
    func scheduleRestEnd(at date: Date, message: RestEndMessage) async {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Self.restTimerIdentifier])
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.restEndDelay(until: date, now: now()), repeats: false)
        let request = UNNotificationRequest(identifier: Self.restTimerIdentifier, content: Self.restEndContent(message),
                                            trigger: trigger)
        try? await center.add(request)
    }

    func cancelRestEnd() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.restTimerIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.restTimerIdentifier])
    }

    /// « Repos terminé » et la série suivante, en Time Sensitive pour passer le mode de concentration Sport (spec M4 §15.2).
    static func restEndContent(_ message: RestEndMessage) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        return content
    }

    /// Le délai jusqu'à la fin du repos ; au moins une seconde, le minimum d'un déclencheur à intervalle.
    static func restEndDelay(until date: Date, now: Date) -> TimeInterval {
        max(1, date.timeIntervalSince(now))
    }
}
