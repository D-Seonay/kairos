import Foundation

/// Cache local des échantillons Apple Santé et des ancres de lecture (spec M2 §5.4).
public protocol HealthSampleCache: Sendable {
    func samples(kind: HealthSampleKind, from: Date, to: Date) async throws -> [CachedHealthSample]
    func replace(kind: HealthSampleKind, with samples: [CachedHealthSample]) async throws
    func insert(_ samples: [CachedHealthSample]) async throws
    func anchor(for kind: HealthSampleKind) async throws -> Data?
    func saveAnchor(_ data: Data, for kind: HealthSampleKind) async throws
    /// Vide échantillons et ancres.
    func clear() async throws
}
