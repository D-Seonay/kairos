import Foundation
import PulseDomain

/// Repli de production quand Apple Santé n'est pas disponible sur l'appareil : chaque appel échoue, l'historique retombe sur le cache.
public struct UnavailableHealthSource: HealthSampleSource {
    public enum Failure: Error, Equatable {
        case unavailable
    }

    public init() {}

    public func requestAuthorization() async throws {
        throw Failure.unavailable
    }

    public func profileHints() async throws -> HealthProfileHints {
        throw Failure.unavailable
    }

    public func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        throw Failure.unavailable
    }
}
