import Foundation

public protocol ScheduledDayRepository: Sendable {
    func days(from: Date, to: Date) async throws -> [ScheduledDay]
    func save(_ day: ScheduledDay) async throws
    func delete(id: UUID) async throws
}
