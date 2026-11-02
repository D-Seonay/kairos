import Foundation
import PulseDomain

/// Passage des enregistrements du cache local aux échantillons que consomme l'agrégation des nuits.
enum CachedSampleMapping {
    static func timedSamples(_ cached: [CachedHealthSample]) -> [TimedSample] {
        cached.compactMap { sample in sample.value.map { TimedSample(date: sample.start, value: $0) } }
    }

    static func sleepIntervals(_ cached: [CachedHealthSample]) -> [SleepInterval] {
        cached.compactMap { sample in sample.sleepStage.map { SleepInterval(start: sample.start, end: sample.end, stage: $0) } }
    }
}
