import Foundation
import PulseDomain

/// Doublure de `HealthReading` pilotée par des valeurs fixes. Si `error` est fourni, chaque méthode le lance.
public struct StubHealthReader: HealthReading {
    public var latest: [HealthDataType: HealthSamplePoint]
    public var counts: [HealthDataType: Int]
    public var sdnn: [TimedSample]
    public var restingHeartRate: [TimedSample]
    public var sleep: [SleepInterval]
    public var error: (any Error)?

    public init(
        latest: [HealthDataType: HealthSamplePoint] = [:],
        counts: [HealthDataType: Int] = [:],
        sdnn: [TimedSample] = [],
        restingHeartRate: [TimedSample] = [],
        sleep: [SleepInterval] = [],
        error: (any Error)? = nil
    ) {
        self.latest = latest
        self.counts = counts
        self.sdnn = sdnn
        self.restingHeartRate = restingHeartRate
        self.sleep = sleep
        self.error = error
    }

    public func requestReadAuthorization() async throws {
        try failIfConfigured()
    }

    public func latestSample(of type: HealthDataType) async throws -> HealthSamplePoint? {
        try failIfConfigured()
        return latest[type]
    }

    /// Ignore les bornes : retourne `counts[type] ?? 0`.
    public func sampleCount(of type: HealthDataType, from: Date, to: Date) async throws -> Int {
        try failIfConfigured()
        return counts[type] ?? 0
    }

    public func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try failIfConfigured()
        return sdnn.filter { (from...to).contains($0.date) }
    }

    public func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try failIfConfigured()
        return restingHeartRate.filter { (from...to).contains($0.date) }
    }

    /// Retient les intervalles dont la fin est dans `[from, to]`.
    public func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        try failIfConfigured()
        return sleep.filter { (from...to).contains($0.end) }
    }

    private func failIfConfigured() throws {
        if let error { throw error }
    }
}
