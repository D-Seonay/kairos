import Foundation
import PulseDomain

/// Source Apple Santé dont toutes les lectures échouent, pour tester le repli sur le cache.
public struct FailingHealthSource: HealthSampleSource {
    public enum Failure: Error, Equatable {
        case unavailable
    }

    public init() {}

    public func requestAuthorization() async throws {
        throw Failure.unavailable
    }

    public func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample] {
        throw Failure.unavailable
    }

    public func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample] {
        throw Failure.unavailable
    }

    public func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        throw Failure.unavailable
    }

    public func profileHints() async throws -> HealthProfileHints {
        throw Failure.unavailable
    }
}
