import Foundation
import PulseContent
import PulseDomain

/// L'annuaire des exercices : le contenu embarqué et les exercices de l'utilisateur, résolus par `ExerciseReference`.
/// Un exercice retiré ou archivé reste résoluble (les anciennes séries le nomment encore) mais n'est plus proposé.
public struct ExerciseDirectory: Sendable {
    private let byReference: [ExerciseReference: ExerciseInfo]
    /// Les exercices proposés, dans l'ordre du contenu puis de la liste de l'utilisateur.
    public let active: [ExerciseInfo]

    public init(library: ContentLibrary, userExercises: [UserExercise]) {
        let infos = library.exercises.map(ExerciseInfo.init(content:)) + userExercises.map(ExerciseInfo.init(user:))
        byReference = Dictionary(infos.map { ($0.reference, $0) }, uniquingKeysWith: { first, _ in first })
        active = infos.filter(\.isActive)
    }

    public func info(_ reference: ExerciseReference) -> ExerciseInfo? {
        byReference[reference]
    }

    /// Le nom français de l'exercice, ou `fallback` (le nom enregistré avec la série) pour une référence inconnue.
    public func name(of reference: ExerciseReference, fallback: String) -> String {
        byReference[reference]?.name ?? fallback
    }

    /// Ce que représente la charge saisie ; une charge externe pour une référence inconnue.
    public func loadKind(of reference: ExerciseReference) -> LoadKind {
        byReference[reference]?.loadKind ?? .external
    }
}
