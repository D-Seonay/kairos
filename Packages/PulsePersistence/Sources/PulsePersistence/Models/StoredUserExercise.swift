import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredUserExercise {
    public var id: UUID = UUID()
    public var name: String = ""
    public var primaryMuscle: String = Muscle.chest.rawValue
    public var secondaryMuscles: Data?
    public var equipment: String = Equipment.machine.rawValue
    public var pattern: String = MovementPattern.horizontalPush.rawValue
    public var region: String = BodyRegion.upper.rawValue
    public var isUnilateral: Bool = false
    public var defaultIncrementKg: Double = 2.5
    public var defaultRestSeconds: Int = 90
    public var isArchived: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ exercise: UserExercise) {
        id = exercise.id
        createdAt = exercise.createdAt
        apply(exercise)
    }

    public func apply(_ exercise: UserExercise) {
        name = exercise.name
        primaryMuscle = exercise.primaryMuscle.rawValue
        secondaryMuscles = CodableColumn.encode(exercise.secondaryMuscles)
        equipment = exercise.equipment.rawValue
        pattern = exercise.pattern.rawValue
        region = exercise.region.rawValue
        isUnilateral = exercise.isUnilateral
        defaultIncrementKg = exercise.defaultIncrementKg
        defaultRestSeconds = exercise.defaultRestSeconds
        isArchived = exercise.isArchived
        updatedAt = exercise.updatedAt
    }

    public func toDomain() -> UserExercise {
        UserExercise(id: id, name: name, primaryMuscle: .stored(primaryMuscle, default: .chest),
                     secondaryMuscles: CodableColumn.decode([Muscle].self, from: secondaryMuscles, default: []),
                     equipment: .stored(equipment, default: .machine), pattern: .stored(pattern, default: .horizontalPush),
                     region: .stored(region, default: .upper), isUnilateral: isUnilateral, defaultIncrementKg: defaultIncrementKg,
                     defaultRestSeconds: defaultRestSeconds, isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt)
    }
}
