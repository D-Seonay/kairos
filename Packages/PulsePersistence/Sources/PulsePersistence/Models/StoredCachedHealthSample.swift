import Foundation
import PulseDomain
import SwiftData

/// Échantillon Apple Santé en cache, local seulement, reconstructible : pas de `deletedAt`.
@Model
public final class StoredCachedHealthSample {
    public var id: UUID = UUID()
    public var kind: String = HealthSampleKind.sdnn.rawValue
    public var start: Date = Date()
    public var end: Date = Date()
    public var value: Double?
    public var sleepStage: String?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var durationMinutes: Double?
    public var healthKitUUID: String?
    public var sourceBundleID: String?
    public var fetchedAt: Date = Date()

    public init(_ sample: CachedHealthSample) {
        id = sample.id
        apply(sample)
    }

    public func apply(_ sample: CachedHealthSample) {
        kind = sample.kind.rawValue
        start = sample.start
        end = sample.end
        value = sample.value
        sleepStage = sample.sleepStage?.rawValue
        distanceMeters = sample.distanceMeters
        averageHeartRate = sample.averageHeartRate
        durationMinutes = sample.durationMinutes
        healthKitUUID = sample.healthKitUUID
        sourceBundleID = sample.sourceBundleID
        fetchedAt = sample.fetchedAt
    }

    public func toDomain() -> CachedHealthSample {
        CachedHealthSample(id: id, kind: .stored(kind, default: .sdnn), start: start, end: end, value: value,
                           sleepStage: sleepStage.flatMap { SleepStage(rawValue: $0) }, distanceMeters: distanceMeters,
                           averageHeartRate: averageHeartRate, durationMinutes: durationMinutes, healthKitUUID: healthKitUUID,
                           sourceBundleID: sourceBundleID, fetchedAt: fetchedAt)
    }
}
