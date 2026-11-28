import Foundation

/// Cache local des échantillons Apple Santé et des ancres de lecture (spec M2 §5.4).
public protocol HealthSampleCache: Sendable {
    func samples(kind: HealthSampleKind, from: Date, to: Date) async throws -> [CachedHealthSample]
    func insert(_ samples: [CachedHealthSample]) async throws
    /// Applique une lecture ancrée en une seule écriture : retire les échantillons du type (tous si lecture complète, sinon ceux
    /// supprimés ou revenus dans `added`), insère `added`, élague ceux du type commencés plus de `healthCacheRetention(for:)` avant
    /// le plus récent, puis enregistre la nouvelle ancre. Les autres types ne bougent pas. Un échec ne laisse rien à moitié.
    func apply(_ changes: HealthSampleChanges) async throws
    func anchor(for kind: HealthSampleKind) async throws -> Data?
    func saveAnchor(_ data: Data, for kind: HealthSampleKind) async throws
    /// Vide échantillons et ancres.
    func clear() async throws
}

/// Ce que le cache garde avant l'échantillon le plus récent d'un type. Les nuits : les 60 que lit le score, plus deux jours de
/// marge (une nuit commence la veille). Les entraînements, le poids et la masse grasse : un an, plus deux jours, pour les
/// statistiques et la courbe de poids (spec M7 §6 et §14).
public func healthCacheRetention(for kind: HealthSampleKind) -> TimeInterval {
    switch kind {
    case .sdnn, .restingHeartRate, .sleep: 62 * 86_400
    case .run, .ride, .otherWorkout, .bodyMass, .bodyFat: 367 * 86_400
    }
}
