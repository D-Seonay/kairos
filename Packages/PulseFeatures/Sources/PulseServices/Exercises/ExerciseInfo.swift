import Foundation
import PulseContent
import PulseDomain

/// Ce que la bibliothèque et les écrans savent d'un exercice, qu'il vienne du contenu embarqué ou de l'utilisateur.
public struct ExerciseInfo: Sendable, Equatable, Identifiable {
    public var reference: ExerciseReference
    public var name: String
    public var englishName: String?
    public var primaryMuscles: [Muscle]
    public var secondaryMuscles: [Muscle]
    public var equipment: Equipment
    public var pattern: MovementPattern
    public var region: BodyRegion
    public var isCompound: Bool
    public var isUnilateral: Bool
    public var loadKind: LoadKind
    public var defaultIncrementKg: Double
    public var defaultRestSeconds: Int
    public var tracksDuration: Bool
    /// Vrai pour un exercice ni retiré du contenu ni archivé par l'utilisateur.
    public var isActive: Bool
    /// L'entrée du catalogue (consignes, erreurs, alternatives, zones à risque) ; nul pour un exercice de l'utilisateur.
    public var content: Exercise?

    public var id: ExerciseReference { reference }

    /// Le groupe du premier muscle principal.
    public var group: MuscleGroup {
        primaryMuscles.first.map(MuscleGroup.init) ?? .core
    }

    public init(content exercise: Exercise) {
        reference = .content(id: exercise.id)
        name = exercise.name.fr
        englishName = exercise.name.en
        primaryMuscles = exercise.primaryMuscles
        secondaryMuscles = exercise.secondaryMuscles
        equipment = exercise.equipment
        pattern = exercise.pattern
        region = exercise.region
        isCompound = exercise.isCompound
        isUnilateral = exercise.isUnilateral
        loadKind = exercise.loadKind
        defaultIncrementKg = exercise.defaultIncrementKg
        defaultRestSeconds = exercise.defaultRestSeconds
        tracksDuration = exercise.tracksDuration
        isActive = !exercise.retired
        content = exercise
    }

    public init(user exercise: UserExercise) {
        reference = .user(id: exercise.id)
        name = exercise.name
        englishName = nil
        primaryMuscles = [exercise.primaryMuscle]
        secondaryMuscles = exercise.secondaryMuscles
        equipment = exercise.equipment
        pattern = exercise.pattern
        region = exercise.region
        isCompound = exercise.isCompound
        isUnilateral = exercise.isUnilateral
        loadKind = exercise.loadKind
        defaultIncrementKg = exercise.defaultIncrementKg
        defaultRestSeconds = exercise.defaultRestSeconds
        tracksDuration = exercise.tracksDuration
        isActive = !exercise.isArchived
        content = nil
    }
}
