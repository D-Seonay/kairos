import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredRoutineDay {
    public var id: UUID = UUID()
    public var order: Int = 0
    public var name: String = ""
    public var kind: String = RoutineDayKind.strength.rawValue
    public var runType: String?
    public var runTargetMinutes: Int?
    public var runTargetKm: Double?
    public var program: StoredProgram?
    @Relationship(deleteRule: .cascade, inverse: \StoredRoutineExercise.day) public var exercises: [StoredRoutineExercise]? = []
    public var deletedAt: Date?

    public init(_ day: RoutineDay) {
        id = day.id
        apply(day)
    }

    public func apply(_ day: RoutineDay) {
        order = day.order
        name = day.name
        kind = day.kind.rawValue
        runType = day.runType?.rawValue
        runTargetMinutes = day.runTargetMinutes
        runTargetKm = day.runTargetKm
        var remaining = Dictionary((exercises ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for exercise in day.exercises {
            if let existing = remaining.removeValue(forKey: exercise.id) {
                existing.deletedAt = nil
                existing.apply(exercise)
            } else {
                let stored = StoredRoutineExercise(exercise)
                stored.day = self
                exercises = (exercises ?? []) + [stored]
            }
        }
        for orphan in remaining.values where orphan.deletedAt == nil {
            orphan.deletedAt = Date()
        }
    }

    /// Suppression logique du jour et de ses exercices.
    func markDeleted() {
        let now = Date()
        deletedAt = now
        for exercise in exercises ?? [] where exercise.deletedAt == nil {
            exercise.deletedAt = now
        }
    }

    public func toDomain() -> RoutineDay {
        RoutineDay(id: id, order: order, name: name, kind: .stored(kind, default: .strength),
                   runType: runType.flatMap { RunType(rawValue: $0) }, runTargetMinutes: runTargetMinutes, runTargetKm: runTargetKm,
                   exercises: (exercises ?? []).filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }.map { $0.toDomain() })
    }
}
