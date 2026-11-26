import Foundation
import Synchronization

/// Ce que Pulse ne fait qu'une fois par appareil. La valeur brute fait la clé retenue.
public enum OnceEvent: String, Sendable, CaseIterable {
    /// L'avis « notifications désactivées » au démarrage d'une séance, quand iOS refuse la notification de fin de repos.
    case notificationsDisabledNotice
}

/// Retient ce qui a déjà eu lieu une fois, d'un lancement à l'autre.
public protocol OnceLog: Sendable {
    func hasHappened(_ event: OnceEvent) -> Bool
    func record(_ event: OnceEvent)
}

/// Journal gardé dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
/// Les clés vivent dans le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsOnceLog: OnceLog {
    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    static func key(for event: OnceEvent) -> String {
        "pulse.once.\(event.rawValue)"
    }

    public func hasHappened(_ event: OnceEvent) -> Bool {
        defaults.bool(forKey: Self.key(for: event))
    }

    public func record(_ event: OnceEvent) {
        defaults.set(true, forKey: Self.key(for: event))
    }
}

/// Journal en mémoire, pour les tests et les aperçus.
public final class InMemoryOnceLog: OnceLog {
    private let events: Mutex<Set<OnceEvent>>

    public init(_ events: Set<OnceEvent> = []) {
        self.events = Mutex(events)
    }

    public func hasHappened(_ event: OnceEvent) -> Bool {
        events.withLock { $0.contains(event) }
    }

    public func record(_ event: OnceEvent) {
        events.withLock { _ = $0.insert(event) }
    }
}
