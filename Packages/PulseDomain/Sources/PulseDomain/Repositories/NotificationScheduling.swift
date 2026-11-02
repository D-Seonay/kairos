/// Planifie la notification du score du matin. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol NotificationScheduling: Sendable {
    /// Remplace la notification du score du matin par celle-ci.
    func scheduleMorningScore(_ message: MorningScoreMessage) async
    /// Retire la notification du score du matin, envoyée ou en attente.
    func cancelMorningScore() async
}

/// Doublure qui garde les messages planifiés, dans l'ordre, et compte les annulations.
public actor StubNotificationScheduler: NotificationScheduling {
    public private(set) var scheduled: [MorningScoreMessage] = []
    public private(set) var cancelCount = 0

    public init() {}

    public func scheduleMorningScore(_ message: MorningScoreMessage) async {
        scheduled.append(message)
    }

    public func cancelMorningScore() async {
        cancelCount += 1
    }
}
