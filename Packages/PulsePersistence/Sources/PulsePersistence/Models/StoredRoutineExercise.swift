import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredRoutineExercise {
    public var id: UUID = UUID()
    public var order: Int = 0
    public var contentExerciseID: String?
    public var userExerciseID: UUID?
    public var sets: Int = 3
    public var repsMin: Int = 8
    public var repsMax: Int = 12
    public var targetRPE: Double = 8
    public var restSeconds: Int = 90
    public var supersetGroup: Int?
    public var day: StoredRoutineDay?
    public var deletedAt: Date?

    public init(_ exercise: RoutineExercise) {
        id = exercise.id
        apply(exercise)
    }

    public func apply(_ exercise: RoutineExercise) {
        order = exercise.order
        contentExerciseID = exercise.exercise.contentID
        userExerciseID = exercise.exercise.userID
        sets = exercise.sets
        repsMin = exercise.repsMin
        repsMax = exercise.repsMax
        targetRPE = exercise.targetRPE
        restSeconds = exercise.restSeconds
        supersetGroup = exercise.supersetGroup
    }

    public func toDomain() -> RoutineExercise {
        RoutineExercise(id: id, order: order,
                        exercise: ExerciseReference(contentID: contentExerciseID, userID: userExerciseID) ?? .content(id: ""),
                        sets: sets, repsMin: repsMin, repsMax: repsMax, targetRPE: targetRPE, restSeconds: restSeconds,
                        supersetGroup: supersetGroup)
    }
}
