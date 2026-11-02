import PulseDomain

/// Tonnage d'une séance : somme de `charge × répétitions` des séries hors échauffement (spec M4 §8.2).
public enum SessionTonnage {
    /// Charge externe : la charge saisie. Poids du corps : le lest éventuel. Assisté : zéro.
    public static func kilograms(of sets: [WorkoutSet], loadKind: (ExerciseReference) -> LoadKind) -> Double {
        sets.reduce(0) { total, set in
            guard set.setType != .warmup, let reps = set.actualReps else { return total }
            switch loadKind(set.exercise) {
            case .external, .bodyweight: return total + (set.actualWeightKg ?? 0) * Double(reps)
            case .assisted: return total
            }
        }
    }
}
