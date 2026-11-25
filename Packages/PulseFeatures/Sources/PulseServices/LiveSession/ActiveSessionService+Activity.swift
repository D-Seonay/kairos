import Foundation
import PulseDomain

/// « Valider » de la Live Activity (écran verrouillé et Dynamic Island étendue) : coche la série suivante affichée, avec la charge
/// et les répétitions proposées, sans ouvrir l'app. La séance réagit comme à la coche de l'écran de séance : repos lancé,
/// notification, activité mise à jour.
extension ActiveSessionService {
    /// Valide `setID` s'il est encore la série que l'activité propose. Une activité en retard sur la séance (série déjà cochée
    /// dans l'app, autre série devenue la suivante, double appui) ne coche rien : rend `nil`, comme sans séance en cours.
    @discardableResult
    public func validateFromActivity(set setID: UUID) async throws -> LiveSession? {
        try await queue.run {
            guard let loaded = try await self.loadSession(), let target = loaded.activityValidation, target.set == setID else {
                return nil
            }
            return try await self.apply(.validate(exercise: target.exercise, set: target.set), to: loaded)
        }
    }
}

extension LiveSession {
    /// La série que « Valider » de la Live Activity coche : la série suivante affichée par l'activité. `nil` pour une séance
    /// passée (sans Live Activity), sans série à faire, ou quand une valeur manque (charge d'un exercice à charge externe,
    /// répétitions ou durée) : l'écran de séance ouvrirait le clavier, l'écran verrouillé ne le peut pas.
    public var activityValidation: (exercise: UUID, set: UUID)? {
        guard !isPastEntry, let next = nextSet(after: lastCheckedSet) else { return nil }
        let exercise = exercises[next.exerciseIndex]
        let set = exercise.sets[next.setIndex]
        guard set.hasValuesToValidate(in: exercise) else { return nil }
        return (exercise.id, set.id)
    }
}

extension LiveSet {
    /// Vrai quand la série se valide telle quelle : ses valeurs (la proposition tant qu'elle n'est pas modifiée) portent une
    /// charge pour un exercice à charge externe, et des répétitions, ou une durée pour un exercice chronométré.
    func hasValuesToValidate(in exercise: LiveExercise) -> Bool {
        let weightKg = isEdited ? self.weightKg : proposed.weightKg
        if exercise.loadKind == .external, weightKg == nil { return false }
        return exercise.tracksDuration
            ? (isEdited ? durationSeconds : proposed.durationSeconds) != nil
            : (isEdited ? reps : proposed.reps) != nil
    }
}
