import Foundation

/// Ce qui empêche la synchronisation iCloud, ramené aux cas qu'on sait expliquer.
public enum CloudSyncProblem: String, Sendable, Equatable, Codable, CaseIterable {
    /// Le stockage iCloud est plein.
    case quotaExceeded
    /// Aucun compte iCloud, ou compte momentanément indisponible.
    case noAccount
    /// Pas de réseau, ou iCloud injoignable.
    case network
    /// iCloud saturé ou qui demande d'attendre (trop de requêtes, zone occupée, service indisponible) : il reprendra seul.
    case busy
    /// Une partie des enregistrements n'est pas passée.
    case partialFailure
    /// Tout le reste.
    case other
}

/// Une synchronisation finie (import, export ou mise en place) : réussie si `problem` est nul.
public struct CloudSyncEvent: Sendable, Equatable {
    public var endDate: Date
    public var problem: CloudSyncProblem?

    public init(endDate: Date, problem: CloudSyncProblem?) {
        self.endDate = endDate
        self.problem = problem
    }
}

/// La dernière synchronisation réussie et la dernière erreur, gardées d'un lancement à l'autre.
public struct CloudSyncStatus: Sendable, Equatable, Codable {
    /// Au-delà, une erreur sans succès depuis est durable : elle peut se montrer ailleurs que dans « Mes données ».
    public static let durableErrorAge: TimeInterval = 24 * 3_600

    public var lastSuccess: Date?
    /// L'erreur de la dernière synchronisation, si elle a échoué ; nulle après un succès.
    public var lastError: CloudSyncProblem?
    public var lastErrorAt: Date?
    /// Le premier échec de la série en cours, sans succès depuis.
    public var failingSince: Date?

    public init(lastSuccess: Date? = nil, lastError: CloudSyncProblem? = nil, lastErrorAt: Date? = nil, failingSince: Date? = nil) {
        self.lastSuccess = lastSuccess
        self.lastError = lastError
        self.lastErrorAt = lastErrorAt
        self.failingSince = failingSince
    }

    /// Note une synchronisation finie ; un événement plus ancien que le dernier noté est ignoré.
    public mutating func record(_ event: CloudSyncEvent) {
        let latest = [lastSuccess, lastErrorAt].compactMap { $0 }.max()
        if let latest, event.endDate < latest { return }
        if let problem = event.problem {
            lastError = problem
            lastErrorAt = event.endDate
            if failingSince == nil { failingSince = event.endDate }
        } else {
            lastSuccess = event.endDate
            lastError = nil
            lastErrorAt = nil
            failingSince = nil
        }
    }

    /// Vrai si la synchronisation échoue depuis plus de 24 h sans un succès.
    public func isDurableError(at now: Date) -> Bool {
        guard lastError != nil, let failingSince else { return false }
        return now.timeIntervalSince(failingSince) >= Self.durableErrorAge
    }
}

/// L'état de la synchronisation iCloud de l'appareil.
public protocol CloudSyncMonitoring: Sendable {
    /// `nil` quand les données ne vont pas dans iCloud (simulateur, mode local, magasin de secours).
    func status() async -> CloudSyncStatus?
}

/// Pas d'iCloud : l'état n'est jamais affiché.
public struct NoCloudSync: CloudSyncMonitoring {
    public init() {}

    public func status() async -> CloudSyncStatus? { nil }
}
