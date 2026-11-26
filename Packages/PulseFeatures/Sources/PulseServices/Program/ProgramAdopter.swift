import Foundation
import PulseContent
import PulseDomain

/// Copie un modèle de programme du bundle en programme de l'utilisateur, adapté à son matériel, à ses zones douloureuses
/// et à ses jours de repos.
public struct ProgramAdopter: Sendable {
    private let library: ContentLibrary
    /// L'annuaire du contenu : il dit quelles séances du modèle sont « jambes lourdes » quand il faut placer des sorties.
    private let directory: ExerciseDirectory

    public init(library: ContentLibrary) {
        self.library = library
        directory = ExerciseDirectory(library: library, userExercises: [])
    }

    /// Sans `split`, le modèle est copié tel quel (l'éditeur de programme). Avec le partage de la semaine que demande
    /// l'onboarding :
    /// - un modèle qui se raccourcit (`canBeShortened`) ne place que ses premières routines de musculation, autant que le
    ///   partage en demande et au moins une ; les autres restent dans le programme, hors semaine. Les autres modèles sont
    ///   adoptés entiers ;
    /// - les sorties qui manquent sont posées par `RunDayPlanner`, une fois la semaine glissée hors des repos obligatoires,
    ///   sans jamais dépasser les séances par semaine demandées ni déplacer une séance de musculation.
    public func adopt(_ template: ProgramTemplate, equipment: EquipmentAccess, painAreas: [PainArea],
                      restWeekdays: [Weekday], split: WeekSplit? = nil, now: Date) -> Program {
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
        if let split, template.canBeShortened {
            // Au moins une séance : un modèle de musculation choisi à la main garde de la musculation, même curseur à fond.
            program.weekLayout = WeekLayoutArranger.keeping(strengthDays: max(1, split.strength), of: program)
        }
        program.weekLayout = WeekLayoutArranger.arrange(program.weekLayout, restWeekdays: restWeekdays)
        program.sessionsPerWeek = program.weekLayout.compactMap { $0 }.count
        guard let split else { return program }
        return RunDayPlanner.adding(runs: split.runs, upTo: split.sessions, to: program, restWeekdays: restWeekdays,
                                    directory: directory)
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
