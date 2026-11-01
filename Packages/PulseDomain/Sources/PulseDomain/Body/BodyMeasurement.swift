import Foundation

public enum MeasurementSource: String, Sendable, Codable, CaseIterable {
    case manual
    case appleHealth
}

/// Poids et masse grasse d'un jour, saisis ou lus dans Apple Santé.
public struct BodyMeasurement: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var weightKg: Double?
    public var bodyFatPercent: Double?
    public var source: MeasurementSource
    public var healthKitUUID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), date: Date, weightKg: Double? = nil, bodyFatPercent: Double? = nil, source: MeasurementSource,
                healthKitUUID: String? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
