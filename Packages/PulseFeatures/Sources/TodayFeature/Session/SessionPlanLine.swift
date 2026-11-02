import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain

/// Une ligne de la séance à suivre en salle : l'exercice, « 3 × 6–10 » et le repos qui suit.
struct SessionPlanLine: Equatable {
    var name: String
    var prescription: String
    var rest: String

    /// Les exercices dans l'ordre de la séance. Dans un super set, on enchaîne sans repos jusqu'au dernier membre du groupe.
    static func lines(for day: RoutineDay, library: ContentLibrary) -> [SessionPlanLine] {
        let exercises = day.exercises.sorted { $0.order < $1.order }
        return exercises.enumerated().map { index, exercise in
            let next = exercises.indices.contains(index + 1) ? exercises[index + 1] : nil
            return SessionPlanLine(name: name(of: exercise.exercise, library: library),
                                   prescription: prescription(exercise), rest: rest(exercise, next: next))
        }
    }

    private static func name(of reference: ExerciseReference, library: ContentLibrary) -> String {
        switch reference {
        case .content(let id): library.exercise(id: id)?.name.fr ?? id
        case .user: String(localized: "Exercice personnel", bundle: .module)
        }
    }

    /// « 3 × 6–10 », ou « 4 × 8 » quand la fourchette n'en est pas une.
    private static func prescription(_ exercise: RoutineExercise) -> String {
        let reps = exercise.repsMin == exercise.repsMax ? "\(exercise.repsMin)" : "\(exercise.repsMin)–\(exercise.repsMax)"
        return "\(exercise.sets) × \(reps)"
    }

    /// « repos 2 min 45 » ; « super set, sans repos » avant un autre membre du groupe, « super set · repos 1 min » après le dernier.
    private static func rest(_ exercise: RoutineExercise, next: RoutineExercise?) -> String {
        let rest = String(localized: "repos \(PulseFormat.restDuration(seconds: exercise.restSeconds))", bundle: .module)
        guard let group = exercise.supersetGroup else { return rest }
        guard next?.supersetGroup != group else { return String(localized: "super set, sans repos", bundle: .module) }
        return String(localized: "super set · \(rest)", bundle: .module)
    }
}
