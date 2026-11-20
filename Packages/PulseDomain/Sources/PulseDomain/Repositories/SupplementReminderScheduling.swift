import Foundation

/// Un rappel de complément ponctuel (spec M5 §7) : un complément, un jour, une heure.
public struct SupplementReminder: Sendable, Equatable {
    public var supplementID: UUID
    /// Minuit local du jour du rappel : l'action « Pris » enregistre la prise pour ce jour-là.
    public var day: Date
    public var fireDate: Date
    public var title: String
    public var body: String

    public init(supplementID: UUID, day: Date, fireDate: Date, title: String, body: String) {
        self.supplementID = supplementID
        self.day = day
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// Planifie les rappels de compléments. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol SupplementReminderScheduling: Sendable {
    /// Remplace tous les rappels de compléments en attente par ceux-ci.
    func replaceSupplementReminders(with reminders: [SupplementReminder]) async
}

/// Doublure qui garde la dernière liste planifiée et compte les remplacements.
public actor StubSupplementReminderScheduler: SupplementReminderScheduling {
    public private(set) var reminders: [SupplementReminder] = []
    public private(set) var replaceCount = 0

    public init() {}

    public func replaceSupplementReminders(with reminders: [SupplementReminder]) async {
        self.reminders = reminders
        replaceCount += 1
    }
}
