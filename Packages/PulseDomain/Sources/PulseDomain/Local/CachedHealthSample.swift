import Foundation

public enum HealthSampleKind: String, Sendable, Codable, CaseIterable {
    case sdnn
    case restingHeartRate
    /// La fréquence cardiaque brute, lue pour la FC la plus basse de la nuit (spec moteur #118).
    case heartRate
    case sleep
    case run
    case ride
    case bodyMass
    case bodyFat
    /// Les entraînements d'Apple Santé autres que course et vélo (natation, HIIT, sports, musculation d'une autre app…). Gardés
    /// dans le cache seulement, jamais en séance : leur famille (`WorkoutFamily`) est dans `value`.
    case otherWorkout
}

/// Un échantillon Apple Santé mis en cache localement, reconstructible (spec M2 §5.4). Jamais synchronisé, jamais exporté.
public struct CachedHealthSample: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var kind: HealthSampleKind
    public var start: Date
    public var end: Date
    public var value: Double?
    public var sleepStage: SleepStage?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var durationMinutes: Double?
    public var healthKitUUID: String?
    public var sourceBundleID: String?
    public var fetchedAt: Date

    public init(id: UUID = UUID(), kind: HealthSampleKind, start: Date, end: Date, value: Double? = nil, sleepStage: SleepStage? = nil,
                distanceMeters: Double? = nil, averageHeartRate: Double? = nil, durationMinutes: Double? = nil,
                healthKitUUID: String? = nil, sourceBundleID: String? = nil, fetchedAt: Date) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.value = value
        self.sleepStage = sleepStage
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.durationMinutes = durationMinutes
        self.healthKitUUID = healthKitUUID
        self.sourceBundleID = sourceBundleID
        self.fetchedAt = fetchedAt
    }
}
