import Foundation
import PulseContent
import PulseDomain

/// Copie un modèle de programme du bundle en programme de l'utilisateur, adapté à son matériel, à ses zones douloureuses
/// et à ses jours de repos.
public struct ProgramAdopter: Sendable {
    private let library: ContentLibrary

    public init(library: ContentLibrary) {
        self.library = library
    }

    public func adopt(_ template: ProgramTemplate, equipment: EquipmentAccess, painAreas: [PainArea],
                      restWeekdays: [Weekday], now: Date) -> Program {
        var program = Program(template: template, now: now)
        program.days = program.days.map { day in
            var day = day
            var used = Set(day.exercises.compactMap(\.exercise.contentID))
            day.exercises = day.exercises.map { routineExercise in
                guard case .content(let original) = routineExercise.exercise else { return routineExercise }
                let replacement = substitute(original, equipment: equipment, painAreas: painAreas, excluding: used)
                guard replacement != original else { return routineExercise }
                used.remove(original)
                used.insert(replacement)
                var replaced = routineExercise
                replaced.exercise = .content(id: replacement)
                return replaced
            }
            return day
        }
        program.weekLayout = WeekLayoutArranger.arrange(program.weekLayout, restWeekdays: restWeekdays)
        program.sessionsPerWeek = program.weekLayout.compactMap { $0 }.count
        return program
    }

    /// L'exercice lui-même s'il convient ; sinon le premier remplaçant acceptable (ses alternatives, puis les exercices actifs
    /// du même plan de mouvement) ; à défaut, l'exercice d'origine.
    public func substitute(_ exerciseID: String, equipment: EquipmentAccess, painAreas: [PainArea],
                           excluding used: Set<String>) -> String {
        guard let exercise = library.exercise(id: exerciseID),
              !isSuitable(exercise, equipment: equipment, painAreas: painAreas) else { return exerciseID }
        let samePattern = library.activeExercises.filter { $0.pattern == exercise.pattern }.map(\.id)
        for candidateID in exercise.alternatives + samePattern where candidateID != exerciseID && !used.contains(candidateID) {
            if let candidate = library.exercise(id: candidateID), !candidate.retired,
               isSuitable(candidate, equipment: equipment, painAreas: painAreas) {
                return candidateID
            }
        }
        return exerciseID
    }

    private func isSuitable(_ exercise: Exercise, equipment: EquipmentAccess, painAreas: [PainArea]) -> Bool {
        equipment.allowedEquipment.contains(exercise.equipment) && exercise.riskAreas.allSatisfy { !painAreas.contains($0) }
    }
}
