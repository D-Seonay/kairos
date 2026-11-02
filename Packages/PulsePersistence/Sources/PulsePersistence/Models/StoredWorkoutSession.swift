import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredWorkoutSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var kind: String = SessionKind.strength.rawValue
    public var source: String = SessionSource.pulse.rawValue
    public var status: String = SessionStatus.inProgress.rawValue
    public var programID: UUID?
    public var routineDayID: UUID?
    public var title: String = ""
    public var appliedAdjustments: Data?
    public var refusedAdjustments: Data?
    public var overallRPE: Double?
    public var note: String?
    public var tonnageKg: Double = 0
    public var durationMinutes: Double?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var estimatedRPE: Double?
    public var healthKitUUID: String?
    public var exerciseNotes: Data?
    @Relationship(deleteRule: .cascade, inverse: \StoredWorkoutSet.session) public var sets: [StoredWorkoutSet]? = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ session: WorkoutSession) {
        id = session.id
        createdAt = session.createdAt
        apply(session)
    }

    public func apply(_ session: WorkoutSession) {
        startedAt = session.startedAt
        endedAt = session.endedAt
        kind = session.kind.rawValue
        source = session.source.rawValue
        status = session.status.rawValue
        programID = session.programID
        routineDayID = session.routineDayID
        title = session.title
        appliedAdjustments = CodableColumn.encode(session.appliedAdjustments)
        refusedAdjustments = CodableColumn.encode(session.refusedAdjustments)
        overallRPE = session.overallRPE
        note = session.note
        tonnageKg = session.tonnageKg
        durationMinutes = session.durationMinutes
        distanceMeters = session.distanceMeters
        averageHeartRate = session.averageHeartRate
        estimatedRPE = session.estimatedRPE
        healthKitUUID = session.healthKitUUID
        exerciseNotes = CodableColumn.encode(session.exerciseNotes)
        updatedAt = session.updatedAt
        applySets(session.sets)
    }

    private func applySets(_ newSets: [WorkoutSet]) {
        var remaining = Dictionary((sets ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for set in newSets {
            if let existing = remaining.removeValue(forKey: set.id) {
                existing.deletedAt = nil
                existing.apply(set, updatedAt: updatedAt)
            } else {
                let stored = StoredWorkoutSet(set, updatedAt: updatedAt)
                stored.session = self
                sets = (sets ?? []) + [stored]
            }
        }
        for orphan in remaining.values where orphan.deletedAt == nil {
            orphan.deletedAt = Date()
        }
    }

    public func toDomain() -> WorkoutSession {
        WorkoutSession(id: id, startedAt: startedAt, endedAt: endedAt, kind: .stored(kind, default: .strength),
                       source: .stored(source, default: .pulse), status: .stored(status, default: .inProgress),
                       programID: programID, routineDayID: routineDayID, title: title,
                       appliedAdjustments: CodableColumn.decode([SessionAdjustment].self, from: appliedAdjustments, default: []),
                       refusedAdjustments: CodableColumn.decode([SessionAdjustment].self, from: refusedAdjustments, default: []),
                       overallRPE: overallRPE, note: note, tonnageKg: tonnageKg, durationMinutes: durationMinutes,
                       distanceMeters: distanceMeters, averageHeartRate: averageHeartRate, estimatedRPE: estimatedRPE,
                       healthKitUUID: healthKitUUID,
                       exerciseNotes: CodableColumn.decode([ExerciseNote].self, from: exerciseNotes, default: []),
                       sets: (sets ?? []).filter { $0.deletedAt == nil }.sorted { $0.order < $1.order }.map { $0.toDomain() },
                       createdAt: createdAt, updatedAt: updatedAt)
    }
}
