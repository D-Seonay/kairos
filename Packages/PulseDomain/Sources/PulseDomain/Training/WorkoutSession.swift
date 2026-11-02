import Foundation

public enum SessionKind: String, Sendable, Codable, CaseIterable {
    case strength
    case run
    case ride
}

public enum SessionSource: String, Sendable, Codable, CaseIterable {
    case pulse
    case appleHealth
    case hevy
}

public enum SessionStatus: String, Sendable, Codable, CaseIterable {
    case inProgress
    case completed
    case abandoned
}

/// Nature d'un ajustement produit par le moteur (spec V1 §6.5, format fixé par la spec M2 §5.3).
public enum AdjustmentKind: String, Sendable, Codable, CaseIterable {
    case volume
    case rpeCap
    case rest
    case load
    case replaceWithMobility
    case suggestRest
    case swapIntervalsForEasy
    case deload
}

/// Un ajustement nommé avec sa raison en français au moment de la génération.
public struct SessionAdjustment: Sendable, Equatable, Codable {
    public var kind: AdjustmentKind
    public var reason: String
    public var value: Double?

    public init(kind: AdjustmentKind, reason: String, value: Double? = nil) {
        self.kind = kind
        self.reason = reason
        self.value = value
    }
}

/// Une séance : musculation Pulse, ou course / vélo lu dans Apple Santé (spec M2 §5.3).
public struct WorkoutSession: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var kind: SessionKind
    public var source: SessionSource
    public var status: SessionStatus
    public var programID: UUID?
    public var routineDayID: UUID?
    public var title: String
    public var appliedAdjustments: [SessionAdjustment]
    public var refusedAdjustments: [SessionAdjustment]
    public var overallRPE: Double?
    public var note: String?
    public var tonnageKg: Double
    public var durationMinutes: Double?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var estimatedRPE: Double?
    public var healthKitUUID: String?
    public var exerciseNotes: [ExerciseNote]
    public var sets: [WorkoutSet]
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil, kind: SessionKind, source: SessionSource,
                status: SessionStatus, programID: UUID? = nil, routineDayID: UUID? = nil, title: String,
                appliedAdjustments: [SessionAdjustment] = [], refusedAdjustments: [SessionAdjustment] = [],
                overallRPE: Double? = nil, note: String? = nil, tonnageKg: Double = 0, durationMinutes: Double? = nil,
                distanceMeters: Double? = nil, averageHeartRate: Double? = nil, estimatedRPE: Double? = nil,
                healthKitUUID: String? = nil, exerciseNotes: [ExerciseNote] = [], sets: [WorkoutSet] = [], createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kind = kind
        self.source = source
        self.status = status
        self.programID = programID
        self.routineDayID = routineDayID
        self.title = title
        self.appliedAdjustments = appliedAdjustments
        self.refusedAdjustments = refusedAdjustments
        self.overallRPE = overallRPE
        self.note = note
        self.tonnageKg = tonnageKg
        self.durationMinutes = durationMinutes
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.estimatedRPE = estimatedRPE
        self.healthKitUUID = healthKitUUID
        self.exerciseNotes = exerciseNotes
        self.sets = sets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
