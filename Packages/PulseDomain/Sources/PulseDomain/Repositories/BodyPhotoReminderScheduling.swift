import Foundation

/// Planifie le rappel de reprendre des photos de corps : des notifications locales neutres, sans image ni mot qui révèle le sujet
/// sur l'écran verrouillé. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol BodyPhotoReminderScheduling: Sendable {
    /// Remplace les rappels de photos de corps en attente par un rappel à chacune de ces dates ; aucune date les retire tous.
    /// Ceux déjà reçus quittent aussi le centre de notifications.
    func replaceBodyPhotoReminders(at dates: [Date]) async
    /// Le nombre de rappels de photos de corps encore en attente.
    func pendingBodyPhotoReminderCount() async -> Int
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

    public func pendingBodyPhotoReminderCount() async -> Int {
        dates.count
    }

    /// Simule le passage de toutes les échéances : plus rien n'est en attente.
    public func deliverAll() {
        dates = []
    }
}
