import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredBodyMeasurement {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var weightKg: Double?
    public var bodyFatPercent: Double?
    public var source: String = MeasurementSource.manual.rawValue
    public var healthKitUUID: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ measurement: BodyMeasurement) {
        id = measurement.id
        createdAt = measurement.createdAt
        apply(measurement)
    }

    public func apply(_ measurement: BodyMeasurement) {
        date = measurement.date
        weightKg = measurement.weightKg
        bodyFatPercent = measurement.bodyFatPercent
        source = measurement.source.rawValue
        healthKitUUID = measurement.healthKitUUID
        updatedAt = measurement.updatedAt
    }

    public func toDomain() -> BodyMeasurement {
        BodyMeasurement(id: id, date: date, weightKg: weightKg, bodyFatPercent: bodyFatPercent, source: .stored(source, default: .manual),
                        healthKitUUID: healthKitUUID, createdAt: createdAt, updatedAt: updatedAt)
    }
}
