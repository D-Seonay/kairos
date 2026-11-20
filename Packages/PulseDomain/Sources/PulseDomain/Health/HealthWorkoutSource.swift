import Foundation

/// Les entraînements qu'Apple Santé apporte à Pulse : les courses et les vélos enregistrés par la montre (spec M6 §3).
public enum WorkoutSignal: String, Sendable, CaseIterable {
    case run
    case ride

    public var kind: HealthSampleKind {
        switch self {
        case .run: .run
        case .ride: .ride
        }
    }

    public var sessionKind: SessionKind {
        switch self {
        case .run: .run
        case .ride: .ride
        }
    }
}

/// Lecture ancrée des entraînements d'Apple Santé. Implémenté par `PulseHealth` ; à part de `HealthSampleSource` pour que les
/// sources qui ne lisent que les nuits n'aient rien à fournir.
public protocol HealthWorkoutSource: Sendable {
    /// Ce qui a changé pour un type d'entraînement depuis `anchor`, en ne regardant que ceux commencés après `start`. Chaque
    /// entraînement ajouté porte son début, sa fin, sa durée, sa distance et sa fréquence cardiaque moyenne quand Apple Santé les a.
    func workoutChanges(of signal: WorkoutSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges
}
