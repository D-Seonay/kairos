import Foundation
import PulseDomain

/// La dernière donnée lue d'un type Apple Santé. HealthKit ne dit jamais si la lecture est refusée : ce n'est pas une autorisation
/// (spec M7 §14).
public struct HealthKindStatus: Sendable, Equatable, Identifiable {
    public var kind: HealthSampleKind
    public var latest: Date?
    public var id: HealthSampleKind { kind }

    public init(kind: HealthSampleKind, latest: Date?) {
        self.kind = kind
        self.latest = latest
    }
}

/// L'état de la lecture Apple Santé, reconstruit depuis le cache local.
public struct HealthReadStatus: Sendable, Equatable {
    /// Un état par `HealthSampleKind.allCases`, dans cet ordre.
    public var kinds: [HealthKindStatus]
    /// Le plus récent `fetchedAt` du cache ; `nil` quand rien n'a été lu.
    public var lastRead: Date?

    public init(kinds: [HealthKindStatus], lastRead: Date?) {
        self.kinds = kinds
        self.lastRead = lastRead
    }

    /// `latest` : le début du dernier échantillon du type, sauf pour le sommeil où une nuit commence la veille : on prend la fin
    /// (le réveil), qui tombe le jour de la donnée.
    public static func read(cache: any HealthSampleCache) async throws -> HealthReadStatus {
        var kinds: [HealthKindStatus] = []
        var lastRead: Date?
        for kind in HealthSampleKind.allCases {
            let samples = try await cache.samples(kind: kind, from: .distantPast, to: .distantFuture)
            let latest = samples.map { kind == .sleep ? $0.end : $0.start }.max()
            kinds.append(HealthKindStatus(kind: kind, latest: latest))
            if let fetched = samples.map(\.fetchedAt).max() { lastRead = max(lastRead ?? fetched, fetched) }
        }
        return HealthReadStatus(kinds: kinds, lastRead: lastRead)
    }
}
