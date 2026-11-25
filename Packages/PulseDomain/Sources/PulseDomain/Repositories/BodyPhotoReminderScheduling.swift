import Foundation

/// Planifie le rappel de reprendre des photos de corps : des notifications locales neutres, sans image ni mot qui révèle le sujet
/// sur l'écran verrouillé. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol BodyPhotoReminderScheduling: Sendable {
    /// Remplace les rappels de photos de corps en attente par un rappel à chacune de ces dates ; aucune date les retire tous.
    func replaceBodyPhotoReminders(at dates: [Date]) async
}

/// Doublure qui garde les dernières dates planifiées et compte les remplacements.
public actor StubBodyPhotoReminderScheduler: BodyPhotoReminderScheduling {
    public private(set) var dates: [Date] = []
    public private(set) var replaceCount = 0

    public init() {}

    public func replaceBodyPhotoReminders(at dates: [Date]) async {
        self.dates = dates
        replaceCount += 1
    }
}
