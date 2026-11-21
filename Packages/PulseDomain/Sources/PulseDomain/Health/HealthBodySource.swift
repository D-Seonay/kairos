import Foundation

/// Les mesures du corps qu'Apple Santé apporte à Pulse : le poids et la masse grasse (spec M7 §14).
public enum BodySignal: String, Sendable, CaseIterable {
    case bodyMass
    case bodyFat

    public var kind: HealthSampleKind {
        switch self {
        case .bodyMass: .bodyMass
        case .bodyFat: .bodyFat
        }
    }
}

/// Lecture ancrée du poids et de la masse grasse d'Apple Santé. Implémenté par `PulseHealth` ; à part de `HealthSampleSource`
/// pour que les sources qui ne lisent que les nuits n'aient rien à fournir.
public protocol HealthBodySource: Sendable {
    /// Comme `workoutChanges` : sans ancre utilisable, lecture complète (`isFullRead`) des échantillons postérieurs à `start`.
    /// `value` en kg pour le poids, en pourcentage 0…100 pour la masse grasse.
    func bodyChanges(of signal: BodySignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges
}
