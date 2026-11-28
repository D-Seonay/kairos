import Foundation
import PulseDomain
import PulseServices
import UserNotifications

// MARK: - Check-in

/// Le rappel quotidien de check-in pour qui n'a pas de montre : « Comment tu te sens ? », avec trois réponses rapides qui
/// enregistrent le check-in sans ouvrir l'app ; touché, il ouvre l'accueil.
extension UserNotificationScheduler: CheckInReminderScheduling {
    /// Le début de l'identifiant d'un rappel de check-in, suivi du jour.
    static let checkInPrefix = "fr.seonay.pulse.check-in."
    static let checkInCategory = "fr.seonay.pulse.check-in"
    /// Le début de l'identifiant d'une réponse rapide, suivi de `CheckInQuickAnswer.rawValue`.
    static let checkInAnswerPrefix = "fr.seonay.pulse.check-in.answer."
    static let checkInDayKey = "checkInDay"

    /// La catégorie des rappels de check-in, avec ses trois réponses : à enregistrer au lancement.
    static var checkInCategories: Set<UNNotificationCategory> {
        let actions = CheckInQuickAnswer.allCases.map { answer in
            UNNotificationAction(identifier: checkInAnswerPrefix + answer.rawValue, title: answer.title, options: [])
        }
        return [UNNotificationCategory(identifier: checkInCategory, actions: actions, intentIdentifiers: [])]
    }

    /// La réponse rapide d'une action ; `nil` pour une autre action.
    static func checkInAnswer(fromAction identifier: String) -> CheckInQuickAnswer? {
        guard identifier.hasPrefix(checkInAnswerPrefix) else { return nil }
        return CheckInQuickAnswer(rawValue: String(identifier.dropFirst(checkInAnswerPrefix.count)))
    }

    /// Retire les rappels de check-in en attente (et ceux reçus si `clearDelivered`), puis planifie ceux-ci, à l'heure locale.
    func replaceCheckInReminders(with reminders: [CheckInReminder], clearDelivered: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.checkInPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        if clearDelivered {
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix(Self.checkInPrefix) }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
        let calendar = Calendar.current
        for reminder in reminders {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let request = UNNotificationRequest(identifier: Self.checkInIdentifier(reminder, calendar: calendar),
                                                content: Self.checkInContent(reminder),
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }

    /// « fr.seonay.pulse.check-in.2026-11-20 ».
    static func checkInIdentifier(_ reminder: CheckInReminder, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: reminder.day)
        return checkInPrefix + String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func checkInContent(_ reminder: CheckInReminder) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.categoryIdentifier = checkInCategory
        content.userInfo = [NotificationRouter.linkKey: AppLink.today.rawValue, checkInDayKey: reminder.day.timeIntervalSince1970]
        return content
    }
}
