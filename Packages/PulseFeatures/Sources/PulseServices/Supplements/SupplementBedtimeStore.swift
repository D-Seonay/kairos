import Foundation
import Synchronization

/// Les compléments « au coucher » qui suivent les nuits (« Suivre mes nuits »), gardés par appareil : l'heure qu'ils suivent
/// vient du cache local d'Apple Santé de cet iPhone, et le réglage reste avec elle.
public protocol SupplementBedtimeStore: Sendable {
    /// Les compléments qui suivent les nuits ; aucun par défaut.
    var followingNights: Set<UUID> { get }
    func setFollowsNights(_ on: Bool, for supplementID: UUID)
}

/// Réglage gardé dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`. La clé vit dans
/// le domaine de la suite, que la suppression totale vide en entier.
public final class UserDefaultsSupplementBedtimeStore: SupplementBedtimeStore {
    static let followingKey = "pulse.supplements.followingNights"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var followingNights: Set<UUID> {
        Set((defaults.stringArray(forKey: Self.followingKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    public func setFollowsNights(_ on: Bool, for supplementID: UUID) {
        var ids = followingNights
        if on { ids.insert(supplementID) } else { ids.remove(supplementID) }
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.followingKey)
    }
}

/// Réglage en mémoire, pour les tests et les aperçus.
public final class InMemorySupplementBedtimeStore: SupplementBedtimeStore {
    private let ids: Mutex<Set<UUID>>

    public init(followingNights: Set<UUID> = []) {
        ids = Mutex(followingNights)
    }

    public var followingNights: Set<UUID> {
        ids.withLock { $0 }
    }

    public func setFollowsNights(_ on: Bool, for supplementID: UUID) {
        ids.withLock { stored in
            if on { stored.insert(supplementID) } else { stored.remove(supplementID) }
        }
    }
}
