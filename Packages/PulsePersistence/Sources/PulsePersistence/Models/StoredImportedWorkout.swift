import Foundation
import PulseDomain
import SwiftData

/// Séance importée d'Apple Health (fréquence cardiaque, durée, distance), gardée dans le magasin local : jamais synchronisée
/// avec iCloud. Une séance importée n'a pas de séries.
@Model
public final class StoredImportedWorkout {
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
                       sets: [], createdAt: createdAt, updatedAt: updatedAt)
    }
}
