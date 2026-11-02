import Foundation

/// Le résultat d'une lecture ancrée d'Apple Santé : ajouts, suppressions et nouvelle ancre d'un type d'échantillon.
public struct HealthSampleChanges: Sendable, Equatable {
    public var kind: HealthSampleKind
    public var added: [CachedHealthSample]
    public var deletedHealthKitUUIDs: [String]
    public var anchor: Data
    /// Vrai quand la lecture repart de zéro : le cache du type est alors remplacé en entier.
    public var isFullRead: Bool

    public init(kind: HealthSampleKind, added: [CachedHealthSample], deletedHealthKitUUIDs: [String], anchor: Data, isFullRead: Bool) {
        self.kind = kind
        self.added = added
        self.deletedHealthKitUUIDs = deletedHealthKitUUIDs
        self.anchor = anchor
        self.isFullRead = isFullRead
    }
}
