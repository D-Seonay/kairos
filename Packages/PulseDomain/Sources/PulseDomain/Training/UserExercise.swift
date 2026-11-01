import Foundation

/// Exercice créé par l'utilisateur, champs minimaux de la spec V1 §5.4. Stocké et synchronisé.
public struct UserExercise: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var primaryMuscle: Muscle
    public var secondaryMuscles: [Muscle]
    public var equipment: Equipment
    public var pattern: MovementPattern
    public var region: BodyRegion
    public var isUnilateral: Bool
    public var defaultIncrementKg: Double
    public var defaultRestSeconds: Int
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, primaryMuscle: Muscle, secondaryMuscles: [Muscle], equipment: Equipment,
                pattern: MovementPattern, region: BodyRegion, isUnilateral: Bool, defaultIncrementKg: Double,
                defaultRestSeconds: Int, isArchived: Bool = false, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.pattern = pattern
        self.region = region
        self.isUnilateral = isUnilateral
        self.defaultIncrementKg = defaultIncrementKg
        self.defaultRestSeconds = defaultRestSeconds
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
