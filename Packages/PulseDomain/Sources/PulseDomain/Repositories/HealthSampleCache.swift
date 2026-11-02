import Foundation

/// Cache local des échantillons Apple Santé et des ancres de lecture (spec M2 §5.4).
public protocol HealthSampleCache: Sendable {
    func samples(kind: HealthSampleKind, from: Date, to: Date) async throws -> [CachedHealthSample]
    func insert(_ samples: [CachedHealthSample]) async throws
    /// Applique une lecture ancrée en une seule écriture : retire les échantillons du type (tous si lecture complète, sinon ceux
    /// supprimés ou revenus dans `added`), insère `added` puis enregistre la nouvelle ancre. Les autres types ne bougent pas.
    func apply(_ changes: HealthSampleChanges) async throws
    func anchor(for kind: HealthSampleKind) async throws -> Data?
    func saveAnchor(_ data: Data, for kind: HealthSampleKind) async throws
    /// Vide échantillons et ancres.
    func clear() async throws
}
