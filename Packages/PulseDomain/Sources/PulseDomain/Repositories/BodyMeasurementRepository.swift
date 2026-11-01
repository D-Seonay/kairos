import Foundation

public protocol BodyMeasurementRepository: Sendable {
    func measurements(from: Date, to: Date) async throws -> [BodyMeasurement]
    func save(_ measurement: BodyMeasurement) async throws
    func delete(id: UUID) async throws
}
