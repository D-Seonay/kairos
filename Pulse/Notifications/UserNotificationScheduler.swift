import Foundation
import PulseDomain
import UserNotifications

/// La notification du score du matin, envoyée tout de suite, celle de la fin du repos, les rappels de compléments, et la
/// suppression des notifications de Pulse.
struct UserNotificationScheduler: NotificationScheduling, NotificationCanceling, RestTimerNotifying, SupplementReminderScheduling {
    static let morningScoreIdentifier = "fr.seonay.pulse.morning-score"
    /// Un seul identifiant : chaque nouveau repos remplace la notification du précédent.
    static let restTimerIdentifier = "fr.seonay.pulse.rest-timer"
    /// Le début de l'identifiant d'un rappel de complément, suivi de l'identifiant du complément et du jour.
    static let supplementPrefix = "fr.seonay.pulse.supplement."
    static let supplementCategory = "fr.seonay.pulse.supplement"
    /// L'action « Pris », qui enregistre la prise sans ouvrir l'app.
    static let supplementTakeAction = "fr.seonay.pulse.supplement.take"
    static let supplementIDKey = "supplementID"
    static let supplementDayKey = "day"

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

    // MARK: - Compléments

    /// La catégorie des rappels de compléments, avec l'action « Pris » : à enregistrer au lancement.
    static var supplementCategories: Set<UNNotificationCategory> {
        let take = UNNotificationAction(identifier: supplementTakeAction, title: String(localized: "Pris"), options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "checkmark"))
        return [UNNotificationCategory(identifier: supplementCategory, actions: [take], intentIdentifiers: [])]
    }

    /// Retire les rappels de compléments en attente, puis planifie ceux-ci, à l'heure locale de chacun.
    func replaceSupplementReminders(with reminders: [SupplementReminder]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.supplementPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let calendar = Calendar.current
        for reminder in reminders {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let request = UNNotificationRequest(identifier: Self.supplementIdentifier(reminder, calendar: calendar),
                                                content: Self.supplementContent(reminder),
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    /// « fr.seonay.pulse.supplement.<id>.2026-11-20 ».
    static func supplementIdentifier(_ reminder: SupplementReminder, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: reminder.day)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "\(supplementPrefix)\(reminder.supplementID.uuidString).\(day)"
    }

    static func supplementContent(_ reminder: SupplementReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.categoryIdentifier = supplementCategory
        content.userInfo = [
            NotificationRouter.linkKey: AppLink.supplements.rawValue,
            supplementIDKey: reminder.supplementID.uuidString,
            supplementDayKey: reminder.day.timeIntervalSince1970
        ]
        return content
    }
}
