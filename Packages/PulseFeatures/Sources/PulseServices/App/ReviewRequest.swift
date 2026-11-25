import Foundation
import Synchronization

/// Quand demander une note sur l'App Store (issue #96). Pur : le nombre de séances, le record et les versions sont lus avant.
///
/// La demande ne se fait qu'au récap d'une séance de musculation terminée en direct : jamais pendant une séance ou une course,
/// ni pendant l'onboarding, puisque seul ce récap l'appelle. Elle vient à partir de la 5e séance terminée, ou plus tôt après un
/// nouveau record, et au plus une fois par version de l'app.
public enum ReviewRequestRule {
    /// Le nombre de séances terminées, celle du récap comprise, à partir duquel Pulse demande une note.
    public static let minimumCompletedSessions = 5

    /// Vrai quand la version est connue, qu'aucune demande n'a été faite pour elle, et que la séance est la 5e terminée au
    /// moins ou qu'elle a battu un record.
    public static func shouldAsk(completedSessions: Int, hasNewRecord: Bool, appVersion: String?,
                                 lastRequestedVersion: String?) -> Bool {
        guard let appVersion, !appVersion.isEmpty, appVersion != lastRequestedVersion else { return false }
        return completedSessions >= minimumCompletedSessions || hasNewRecord
    }
}

/// La dernière version de l'app pour laquelle une note a été demandée, gardée par appareil.
public protocol ReviewRequestStore: Sendable {
    var lastRequestedVersion: String? { get }
    func setLastRequestedVersion(_ version: String)
}

/// Version gardée dans `UserDefaults`. Seul le nom de la suite est retenu : `UserDefaults` n'est pas `Sendable`.
public final class UserDefaultsReviewRequestStore: ReviewRequestStore {
    static let lastRequestedVersionKey = "pulse.review.lastRequestedVersion"

    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var lastRequestedVersion: String? {
        defaults.string(forKey: Self.lastRequestedVersionKey)
    }

    public func setLastRequestedVersion(_ version: String) {
        defaults.set(version, forKey: Self.lastRequestedVersionKey)
    }
}

/// Version en mémoire, pour les tests et les aperçus.
public final class InMemoryReviewRequestStore: ReviewRequestStore {
    private let version: Mutex<String?>

    public init(lastRequestedVersion: String? = nil) {
        version = Mutex(lastRequestedVersion)
    }

    public var lastRequestedVersion: String? {
        version.withLock { $0 }
    }

    public func setLastRequestedVersion(_ version: String) {
        self.version.withLock { $0 = version }
    }
}

/// La demande de note de l'app : la règle, la version courante (`CFBundleShortVersionString`) et sa mémoire.
public struct ReviewPrompt: Sendable {
    /// La page « Écrire un avis » de Pulse sur l'App Store, pour le lien des Paramètres.
    public static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6829265826?action=write-review")

    private let store: any ReviewRequestStore
    private let appVersion: String?

    public init(store: any ReviewRequestStore, appVersion: String?) {
        self.store = store
        self.appVersion = appVersion
    }

    /// Vrai quand la règle demande une note : la version est alors retenue, pour ne plus redemander avant la suivante, même
    /// si iOS choisit de ne rien afficher.
    public func claim(completedSessions: Int, hasNewRecord: Bool) -> Bool {
        guard let appVersion, ReviewRequestRule.shouldAsk(completedSessions: completedSessions, hasNewRecord: hasNewRecord,
                                                          appVersion: appVersion,
                                                          lastRequestedVersion: store.lastRequestedVersion) else { return false }
        store.setLastRequestedVersion(appVersion)
        return true
    }
}
