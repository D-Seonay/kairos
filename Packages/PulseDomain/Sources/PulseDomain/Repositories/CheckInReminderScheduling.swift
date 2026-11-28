import Foundation

/// Un rappel de check-in ponctuel : un matin, une heure, un titre et un corps déjà écrits.
public struct CheckInReminder: Sendable, Equatable {
    /// Minuit local du jour du check-in demandé.
    public var day: Date
    public var fireDate: Date
    public var title: String
    public var body: String

    public init(day: Date, fireDate: Date, title: String, body: String) {
        self.day = day
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// Planifie les rappels de check-in. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol CheckInReminderScheduling: Sendable {
    /// Remplace tous les rappels de check-in en attente par ceux-ci ; `clearDelivered` retire aussi ceux déjà reçus (le check-in
    /// du jour est fait, ou le rappel n'a plus lieu d'être).
    func replaceCheckInReminders(with reminders: [CheckInReminder], clearDelivered: Bool) async
}

/// Doublure qui garde la dernière liste planifiée et compte les remplacements.
public actor StubCheckInReminderScheduler: CheckInReminderScheduling {
    public private(set) var reminders: [CheckInReminder] = []
    public private(set) var replaceCount = 0
    public private(set) var clearedDelivered = false

    public init() {}

    public func replaceCheckInReminders(with reminders: [CheckInReminder], clearDelivered: Bool) async {
        self.reminders = reminders
        replaceCount += 1
        clearedDelivered = clearDelivered
    }
}
