import Foundation
import PulseServices

/// La progression d'un exercice et de la séance, échauffements compris : ce qui allume l'anneau d'une carte, fête la fin d'un
/// exercice et fait respirer « Terminer ».
extension LiveExercise {
    /// Les séries validées de l'exercice.
    var doneSetCount: Int {
        sets.count(where: { $0.completedAt != nil })
    }

    /// Vrai quand l'exercice a au moins une série et qu'elles sont toutes validées.
    var isDone: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.completedAt != nil }
    }
}

extension LiveSession {
    /// Vrai quand la séance a au moins un exercice et que toutes ses séries sont validées.
    var isDone: Bool {
        !exercises.isEmpty && exercises.allSatisfy(\.isDone)
    }

    /// La série à faire maintenant : la première non validée qui suit la dernière validée, comme le bandeau de repos.
    var upcomingSetID: UUID? {
        nextSet(after: lastCheckedSet).map { exercises[$0.exerciseIndex].sets[$0.setIndex].id }
    }
}
