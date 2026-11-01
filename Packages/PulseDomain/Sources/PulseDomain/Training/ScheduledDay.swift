import Foundation

public enum ScheduledDayKind: String, Sendable, Codable, CaseIterable {
    case strength
    case run
    case rest
}

public enum ScheduledDayStatus: String, Sendable, Codable, CaseIterable {
    case planned
    case completed
    case skipped
}

public enum MoveReason: String, Sendable, Codable, CaseIterable {
    case antiInterferenceAfterHeavyLegs
    case antiInterferenceSameDay
    case antiInterferenceRestDay
    case user
}

/// Un jour de la semaine datée : séance placée, déplacée, validée (spec M2 §5.3 ; rempli en M6).
public struct ScheduledDay: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var programID: UUID?
    public var routineDayID: UUID?
    public var title: String
    public var kind: ScheduledDayKind
    public var status: ScheduledDayStatus
    public var movedFromDate: Date?
    public var moveReason: MoveReason?
    public var moveReasonText: String?
    public var validatedManually: Bool
    public var sessionID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), date: Date, programID: UUID? = nil, routineDayID: UUID? = nil, title: String,
                kind: ScheduledDayKind, status: ScheduledDayStatus, movedFromDate: Date? = nil, moveReason: MoveReason? = nil,
                moveReasonText: String? = nil, validatedManually: Bool = false, sessionID: UUID? = nil,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.programID = programID
        self.routineDayID = routineDayID
        self.title = title
        self.kind = kind
        self.status = status
        self.movedFromDate = movedFromDate
        self.moveReason = moveReason
        self.moveReasonText = moveReasonText
        self.validatedManually = validatedManually
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
