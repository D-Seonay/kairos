import Foundation

/// Demande d'autorisation des notifications. Implémenté par l'app au-dessus de `UNUserNotificationCenter`.
public protocol NotificationAuthorizing: Sendable {
    /// Renvoie vrai si l'utilisateur autorise les notifications.
    func requestAuthorization() async -> Bool
}

/// Doublure qui répond `granted` et compte les demandes.
public actor StubNotificationAuthorizer: NotificationAuthorizing {
    private let granted: Bool
    public private(set) var requestCount = 0

    public init(granted: Bool) {
        self.granted = granted
    }

    public func requestAuthorization() async -> Bool {
        requestCount += 1
        return granted
    }
}
