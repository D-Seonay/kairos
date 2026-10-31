import Foundation
import PulseDomain

/// Lecture d'Apple Santé derrière un protocole, pour que l'app et les tests utilisent une doublure.
public protocol HealthReading: Sendable {
    func requestReadAuthorization() async throws
    func latestSample(of type: HealthDataType) async throws -> HealthSamplePoint?
    func sampleCount(of type: HealthDataType, from: Date, to: Date) async throws -> Int
    func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample]
    func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample]
    func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval]
}
