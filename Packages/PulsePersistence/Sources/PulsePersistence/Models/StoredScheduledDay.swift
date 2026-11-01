import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredScheduledDay {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var programID: UUID?
    public var routineDayID: UUID?
    public var title: String = ""
    public var kind: String = ScheduledDayKind.strength.rawValue
    public var status: String = ScheduledDayStatus.planned.rawValue
    public var movedFromDate: Date?
    public var moveReason: String?
    public var moveReasonText: String?
    public var validatedManually: Bool = false
    public var sessionID: UUID?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ day: ScheduledDay) {
        id = day.id
        createdAt = day.createdAt
        apply(day)
    }

    public func apply(_ day: ScheduledDay) {
        date = day.date
        programID = day.programID
        routineDayID = day.routineDayID
        title = day.title
        kind = day.kind.rawValue
        status = day.status.rawValue
        movedFromDate = day.movedFromDate
        moveReason = day.moveReason?.rawValue
        moveReasonText = day.moveReasonText
        validatedManually = day.validatedManually
        sessionID = day.sessionID
        updatedAt = day.updatedAt
    }

    public func toDomain() -> ScheduledDay {
        ScheduledDay(id: id, date: date, programID: programID, routineDayID: routineDayID, title: title,
                     kind: .stored(kind, default: .strength), status: .stored(status, default: .planned), movedFromDate: movedFromDate,
                     moveReason: moveReason.flatMap { MoveReason(rawValue: $0) }, moveReasonText: moveReasonText,
                     validatedManually: validatedManually, sessionID: sessionID, createdAt: createdAt, updatedAt: updatedAt)
    }
}
