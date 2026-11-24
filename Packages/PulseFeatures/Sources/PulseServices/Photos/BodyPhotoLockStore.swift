import Foundation
import Synchronization

/// Le réglage « Verrouiller avec Face ID » des photos de corps, gardé par appareil.
public protocol BodyPhotoLockStore: Sendable {
    /// Vrai par défaut, tant que l'utilisateur ne l'a pas coupé.
    var isLockEnabled: Bool { get }
    func setLockEnabled(_ on: Bool)
}

/// Réglage gardé dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
public final class UserDefaultsBodyPhotoLockStore: BodyPhotoLockStore {
    static let lockEnabledKey = "pulse.bodyPhotos.lockEnabled"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var isLockEnabled: Bool {
        defaults.object(forKey: Self.lockEnabledKey) as? Bool ?? true
    }

    public func setLockEnabled(_ on: Bool) {
        defaults.set(on, forKey: Self.lockEnabledKey)
    }
}

/// Réglage en mémoire, pour les tests et les aperçus.
public final class InMemoryBodyPhotoLockStore: BodyPhotoLockStore {
    private let enabled: Mutex<Bool>

    public init(isLockEnabled: Bool = true) {
        enabled = Mutex(isLockEnabled)
    }

    public var isLockEnabled: Bool {
        enabled.withLock { $0 }
    }

    public func setLockEnabled(_ on: Bool) {
        enabled.withLock { $0 = on }
    }
}
