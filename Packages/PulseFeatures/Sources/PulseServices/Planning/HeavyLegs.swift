import Foundation
import PulseDomain

/// Dit si une séance est « jambes lourdes » (spec M6 §9) : plus de la moitié de ses séries de travail visent les quadriceps,
/// les ischios ou les fessiers, par un de leurs muscles principaux.
public enum HeavyLegs {
    static let legMuscles: Set<Muscle> = [.quads, .hamstrings, .glutes]

    /// Les séries de la routine : un jour de course n'est jamais « jambes lourdes ».
    public static func isHeavy(_ day: RoutineDay, directory: ExerciseDirectory) -> Bool {
        guard day.kind == .strength else { return false }
        return isHeavy(day.exercises.map { ($0.exercise, max(0, $0.sets)) }, directory: directory)
    }

    /// Les séries enregistrées hors échauffement d'une séance de musculation.
    public static func isHeavy(_ session: WorkoutSession, directory: ExerciseDirectory) -> Bool {
        guard session.kind == .strength else { return false }
        return isHeavy(session.sets.filter { $0.setType != .warmup }.map { ($0.exercise, 1) }, directory: directory)
    }

    private static func isHeavy(_ sets: [(ExerciseReference, Int)], directory: ExerciseDirectory) -> Bool {
        let total = sets.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return false }
        let legs = sets.reduce(0) { count, entry in
            let muscles = directory.info(entry.0)?.primaryMuscles ?? []
            return legMuscles.isDisjoint(with: muscles) ? count : count + entry.1
        }
        return legs * 2 > total
    }
}
