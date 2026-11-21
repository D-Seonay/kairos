import Foundation
import PulseDomain
import Synchronization

/// La fenêtre, en jours, sur laquelle la dernière lecture d'Apple Santé a réussi pour chaque type. Quand `WorkoutHistory` lit une
/// fenêtre plus large, l'ancre de lecture ne suffit plus : il faut relire une fois en entier.
public protocol HealthReadWindowStore: Sendable {
    func days(for kind: HealthSampleKind) -> Int?
    func save(days: Int, for kind: HealthSampleKind)
}

/// Fenêtres gardées dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
/// Les clés vivent dans le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsHealthReadWindowStore: HealthReadWindowStore {
    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    static func key(for kind: HealthSampleKind) -> String {
        "pulse.healthReadWindow.\(kind.rawValue)"
    }

    public func days(for kind: HealthSampleKind) -> Int? {
        defaults.object(forKey: Self.key(for: kind)) as? Int
    }

    public func save(days: Int, for kind: HealthSampleKind) {
        defaults.set(days, forKey: Self.key(for: kind))
    }
}

/// Fenêtres en mémoire, pour les tests et les aperçus.
public final class InMemoryHealthReadWindowStore: HealthReadWindowStore {
    private let stored = Mutex<[HealthSampleKind: Int]>([:])

    public init() {}

    public func days(for kind: HealthSampleKind) -> Int? {
        stored.withLock { $0[kind] }
    }

    public func save(days: Int, for kind: HealthSampleKind) {
        stored.withLock { $0[kind] = days }
    }
}
