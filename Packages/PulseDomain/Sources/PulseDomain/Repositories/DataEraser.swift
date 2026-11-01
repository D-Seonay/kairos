/// Options de la suppression totale (spec M2 §7).
public struct EraseOptions: Sendable, Equatable {
    public var includeAppleHealth: Bool

    public init(includeAppleHealth: Bool) {
        self.includeAppleHealth = includeAppleHealth
    }
}

public protocol DataEraser: Sendable {
    func eraseEverything(options: EraseOptions) async throws
}

/// Annulation des notifications locales planifiées (implémentée en M5).
public protocol NotificationCanceling: Sendable {
    func cancelAllScheduled() async
}
