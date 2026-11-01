import Foundation
import PulseDomain

/// Passage entre les échantillons bruts de `HealthSampleSource` et les enregistrements du cache local.
enum CachedSampleMapping {
    static func cached(_ samples: [TimedSample], kind: HealthSampleKind, fetchedAt: Date) -> [CachedHealthSample] {
        samples.map { CachedHealthSample(kind: kind, start: $0.date, end: $0.date, value: $0.value, fetchedAt: fetchedAt) }
    }

    static func cached(_ intervals: [SleepInterval], fetchedAt: Date) -> [CachedHealthSample] {
        intervals.map { CachedHealthSample(kind: .sleep, start: $0.start, end: $0.end, sleepStage: $0.stage, fetchedAt: fetchedAt) }
    }

    static func timedSamples(_ cached: [CachedHealthSample]) -> [TimedSample] {
        cached.compactMap { sample in sample.value.map { TimedSample(date: sample.start, value: $0) } }
    }

    static func sleepIntervals(_ cached: [CachedHealthSample]) -> [SleepInterval] {
        cached.compactMap { sample in sample.sleepStage.map { SleepInterval(start: sample.start, end: sample.end, stage: $0) } }
    }
}
