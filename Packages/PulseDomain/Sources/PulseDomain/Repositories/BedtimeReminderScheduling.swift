import Foundation

/// Un rappel de coucher ponctuel : un soir, une heure, un titre et un corps déjà écrits.
public struct BedtimeReminder: Sendable, Equatable {
    /// Minuit local du soir concerné : un rappel qui sonne après minuit reste celui de la veille.
    public var evening: Date
    public var fireDate: Date
    public var title: String
    public var body: String

    public init(evening: Date, fireDate: Date, title: String, body: String) {
        self.evening = evening
        self.fireDate = fireDate
        self.title = title
        self.body = body
    }
}

/// Planifie les rappels de coucher. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol BedtimeReminderScheduling: Sendable {
    /// Remplace tous les rappels de coucher en attente par ceux-ci.
    func replaceBedtimeReminders(with reminders: [BedtimeReminder]) async
}

/// Doublure qui garde la dernière liste planifiée et compte les remplacements.
public actor StubBedtimeReminderScheduler: BedtimeReminderScheduling {
    public private(set) var reminders: [BedtimeReminder] = []
    public private(set) var replaceCount = 0

    public init() {}

    public func replaceBedtimeReminders(with reminders: [BedtimeReminder]) async {
        self.reminders = reminders
        replaceCount += 1
    }
}
