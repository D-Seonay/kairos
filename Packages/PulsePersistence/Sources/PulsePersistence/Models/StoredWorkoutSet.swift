import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredWorkoutSet {
    public var id: UUID = UUID()
    public var order: Int = 0
    public var contentExerciseID: String?
    public var userExerciseID: UUID?
    public var exerciseName: String = ""
    public var setType: String = SetType.working.rawValue
    public var supersetGroup: Int?
    public var plannedWeightKg: Double?
    public var plannedReps: Int?
    public var actualWeightKg: Double?
    public var actualReps: Int?
    public var rpe: Double?
    public var restSeconds: Int?
    public var completedAt: Date?
    public var isPersonalRecord: Bool = false
    public var replacedContentExerciseID: String?
    public var replacedUserExerciseID: UUID?
    public var replacementReason: String?
    public var session: StoredWorkoutSession?
    public var deletedAt: Date?

    public init(_ set: WorkoutSet) {
        id = set.id
        apply(set)
    }

    public func apply(_ set: WorkoutSet) {
        order = set.order
        contentExerciseID = set.exercise.contentID
        userExerciseID = set.exercise.userID
        exerciseName = set.exerciseName
        setType = set.setType.rawValue
        supersetGroup = set.supersetGroup
        plannedWeightKg = set.plannedWeightKg
        plannedReps = set.plannedReps
        actualWeightKg = set.actualWeightKg
        actualReps = set.actualReps
        rpe = set.rpe
        restSeconds = set.restSeconds
        completedAt = set.completedAt
        isPersonalRecord = set.isPersonalRecord
        replacedContentExerciseID = set.replacedExercise?.contentID
        replacedUserExerciseID = set.replacedExercise?.userID
        replacementReason = set.replacementReason?.rawValue
    }

    public func toDomain() -> WorkoutSet {
        WorkoutSet(id: id, order: order,
                   exercise: ExerciseReference(contentID: contentExerciseID, userID: userExerciseID) ?? .content(id: ""),
                   exerciseName: exerciseName, setType: .stored(setType, default: .working), supersetGroup: supersetGroup,
                   plannedWeightKg: plannedWeightKg, plannedReps: plannedReps, actualWeightKg: actualWeightKg, actualReps: actualReps,
                   rpe: rpe, restSeconds: restSeconds, completedAt: completedAt, isPersonalRecord: isPersonalRecord,
                   replacedExercise: ExerciseReference(contentID: replacedContentExerciseID, userID: replacedUserExerciseID),
                   replacementReason: replacementReason.flatMap { ReplacementReason(rawValue: $0) })
    }
}
