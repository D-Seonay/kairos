import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Convertit une séance de l'export Hevy en séance Pulse (spec M4 §13.2).
public enum HevySessionBuilder {
    /// `references` associe un nom d'exercice Hevy à l'exercice Pulse ; les noms absents sont ignorés, tout comme les lignes sans
    /// charge, sans répétitions et sans durée. `nil` quand il ne reste aucune série.
    public static func session(from workout: HevyWorkout, references: [String: ExerciseReference], directory: ExerciseDirectory,
                               now: Date) -> WorkoutSession? {
        var sets: [WorkoutSet] = []
        var notes: [ExerciseNote] = []
        for block in workout.exercises {
            guard let reference = references[block.name] else { continue }
            let name = directory.name(of: reference, fallback: block.name)
            let kept = block.sets.filter(hasValues)
            guard !kept.isEmpty else { continue }
            for row in kept {
                sets.append(WorkoutSet(
                    order: sets.count, exercise: reference, exerciseName: name, setType: setType(row.setType),
                    supersetGroup: block.supersetID.map { $0 + 1 }, actualWeightKg: row.weightKg, actualReps: row.reps,
                    durationSeconds: row.durationSeconds, rpe: row.rpe))
            }
            if let text = block.notes { notes.append(ExerciseNote(exercise: reference, text: text)) }
        }
        guard !sets.isEmpty else { return nil }
        // L'export n'a pas de décalage horaire : autour du passage à l'heure d'hiver, la fin peut précéder le début. Elle est
        // ramenée au début, pour que l'intervalle de la séance ne soit jamais inversé.
        let endedAt = max(workout.endedAt, workout.startedAt)
        return WorkoutSession(
            startedAt: workout.startedAt, endedAt: endedAt, kind: .strength, source: .hevy, status: .completed,
            title: workout.title, note: workout.description,
            tonnageKg: SessionTonnage.kilograms(of: sets, loadKind: directory.loadKind(of:)),
            durationMinutes: endedAt.timeIntervalSince(workout.startedAt) / 60, exerciseNotes: notes, sets: sets,
            createdAt: now, updatedAt: now)
    }

    private static func hasValues(_ row: HevyRow) -> Bool {
        (row.weightKg ?? 0) > 0 || (row.reps ?? 0) > 0 || (row.durationSeconds ?? 0) > 0
    }

    private static func setType(_ hevyType: String) -> SetType {
        switch hevyType.trimmingCharacters(in: .whitespaces).lowercased() {
        case "warmup": .warmup
        case "dropset": .drop
        case "failure": .failure
        default: .working
        }
    }
}
