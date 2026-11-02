import Foundation
import PulseDomain

/// Un exercice perso à créer pour un nom Hevy inconnu : ce que l'import a deviné, à relire avant de créer.
public struct UserExerciseDraft: Sendable, Equatable, Codable {
    public var name: String
    public var primaryMuscle: Muscle
    public var secondaryMuscles: [Muscle]
    public var equipment: Equipment
    public var pattern: MovementPattern
    public var region: BodyRegion
    public var loadKind: LoadKind
    public var isUnilateral: Bool
    public var needsReview: Bool

    public init(name: String, primaryMuscle: Muscle, secondaryMuscles: [Muscle], equipment: Equipment, pattern: MovementPattern,
                region: BodyRegion, loadKind: LoadKind, isUnilateral: Bool, needsReview: Bool) {
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.pattern = pattern
        self.region = region
        self.loadKind = loadKind
        self.isUnilateral = isUnilateral
        self.needsReview = needsReview
    }

    /// L'exercice perso : incrément de 2,5 kg (5 kg pour le bas du corps), repos de 90 s, composé pour les poussées, tirages,
    /// squats et charnières.
    public func userExercise(id: UUID, now: Date) -> UserExercise {
        UserExercise(id: id, name: name, primaryMuscle: primaryMuscle, secondaryMuscles: secondaryMuscles, equipment: equipment,
                     pattern: pattern, region: region, isUnilateral: isUnilateral, defaultIncrementKg: region == .lower ? 5 : 2.5,
                     defaultRestSeconds: 90, loadKind: loadKind, isCompound: Self.compoundPatterns.contains(pattern),
                     createdAt: now, updatedAt: now)
    }

    private static let compoundPatterns: Set<MovementPattern> = [
        .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .squat, .hinge
    ]
}

/// Ce que devient un nom d'exercice Hevy à l'import.
public enum HevyMappingChoice: Sendable, Equatable, Codable {
    /// Un exercice du contenu embarqué.
    case content(id: String)
    /// Un exercice perso existant.
    case user(id: UUID)
    /// Un exercice perso à créer.
    case create(UserExerciseDraft)
    /// Les séries de ce nom ne sont pas importées.
    case ignore
}
