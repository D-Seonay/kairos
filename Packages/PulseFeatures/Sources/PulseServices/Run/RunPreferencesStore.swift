import Foundation
import Synchronization

/// Les réglages de la course, gardés par appareil : pour l'instant, les annonces vocales à chaque kilomètre.
public protocol RunPreferencesStore: Sendable {
    /// Vrai par défaut, tant que l'utilisateur ne les a pas coupées.
    var announcesKilometres: Bool { get }
    func setAnnouncesKilometres(_ on: Bool)
}

/// Réglages gardés dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
public final class UserDefaultsRunPreferencesStore: RunPreferencesStore {
    static let announcesKilometresKey = "pulse.run.announcesKilometres"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var announcesKilometres: Bool {
        defaults.object(forKey: Self.announcesKilometresKey) as? Bool ?? true
    }

    public func setAnnouncesKilometres(_ on: Bool) {
        defaults.set(on, forKey: Self.announcesKilometresKey)
    }
}

/// Réglages en mémoire, pour les tests et les aperçus.
public final class InMemoryRunPreferencesStore: RunPreferencesStore {
    private let announces: Mutex<Bool>

    public init(announcesKilometres: Bool = true) {
        announces = Mutex(announcesKilometres)
    }

    public var announcesKilometres: Bool {
        announces.withLock { $0 }
    }

    public func setAnnouncesKilometres(_ on: Bool) {
        announces.withLock { $0 = on }
    }
}
