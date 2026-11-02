import Foundation

/// Texte de la notification de fin de repos. Ne contient que le nom de l'exercice et la série prévue.
public struct RestEndMessage: Sendable, Equatable {
    public var title: String
    public var body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// Planifie la notification de fin de repos. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol RestTimerNotifying: Sendable {
    /// Remplace la notification de fin de repos par celle-ci, à la date donnée.
    func scheduleRestEnd(at date: Date, message: RestEndMessage) async
    /// Retire la notification de fin de repos, envoyée ou en attente.
    func cancelRestEnd() async
}

/// Doublure qui garde les planifications, dans l'ordre, et compte les annulations.
public actor StubRestTimerNotifier: RestTimerNotifying {
    /// Une planification enregistrée.
    public struct Scheduled: Sendable, Equatable {
        public var date: Date
        public var message: RestEndMessage
    }

    public private(set) var scheduled: [Scheduled] = []
    public private(set) var cancelCount = 0

    public init() {}

    public func scheduleRestEnd(at date: Date, message: RestEndMessage) async {
        scheduled.append(Scheduled(date: date, message: message))
    }

    public func cancelRestEnd() async {
        cancelCount += 1
    }
}
