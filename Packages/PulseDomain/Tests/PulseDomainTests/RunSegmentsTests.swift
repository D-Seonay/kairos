import Foundation
@testable import PulseDomain
import Testing

@Suite("Meilleur segment d'une course")
struct RunSegmentsTests {
    /// Une sortie à allure par kilomètre donnée, un instant par kilomètre : `paces[i]` est le temps du (i+1)e km.
    private static func kilometres(_ paces: [Double]) -> [RunSegmentSample] {
        var samples = [RunSegmentSample(seconds: 0, meters: 0)]
        for pace in paces {
            let last = samples[samples.count - 1]
            samples.append(RunSegmentSample(seconds: last.seconds + pace, meters: last.meters + 1_000))
        }
        return samples
    }

    @Test("un 5 km rapide au milieu d'une sortie de 12 km est trouvé, pas l'allure moyenne")
    func fastFiveKInsideALongerRun() throws {
        // 3 km à 6:00, 5 km à 4:30, 4 km à 6:00.
        let samples = Self.kilometres(Array(repeating: 360, count: 3) + Array(repeating: 270, count: 5)
            + Array(repeating: 360, count: 4))
        let best = try #require(RunSegments.fastest(meters: 5_000, in: samples))
        #expect(best == 1_350)
        let average = samples[samples.count - 1].seconds * 5_000 / 12_000
        #expect(best < average)
    }

    @Test("le bord de la fenêtre tombe entre deux instants : il est interpolé")
    func windowEdgeIsInterpolated() throws {
        // 0 → 1 000 m en 300 s, puis 1 000 → 3 000 m en 400 s (allure plus rapide) : le meilleur 1,5 km est dans la partie
        // rapide, ses deux bords entre deux instants.
        let samples = [RunSegmentSample(seconds: 0, meters: 0), RunSegmentSample(seconds: 300, meters: 1_000),
                       RunSegmentSample(seconds: 700, meters: 3_000)]
        #expect(RunSegments.fastest(meters: 1_500, in: samples) == 300)
        // 2 500 m : la fenêtre doit déborder sur la partie lente, de 500 m à 3 000 m.
        #expect(RunSegments.fastest(meters: 2_500, in: samples) == 550)
    }

    @Test("une distance couverte tout juste rend le temps total ; une plus longue ne rend rien")
    func exactAndTooLongDistances() {
        let samples = Self.kilometres([300, 310, 320, 330, 340])
        #expect(RunSegments.fastest(meters: 5_000, in: samples) == 1_600)
        #expect(RunSegments.fastest(meters: 5_001, in: samples) == nil)
        #expect(RunSegments.fastest(meters: 1_000, in: samples) == 300)
        #expect(RunSegments.fastest(meters: 1_000, in: []) == nil)
        #expect(RunSegments.fastest(meters: 0, in: samples) == nil)
    }

    @Test("un arrêt (distance immobile) n'est compté que s'il est dans la fenêtre")
    func stopsOnlyCountInsideTheWindow() throws {
        // 2 km en 600 s, arrêt de 120 s, 2 km en 500 s.
        let samples = [RunSegmentSample(seconds: 0, meters: 0), RunSegmentSample(seconds: 600, meters: 2_000),
                       RunSegmentSample(seconds: 720, meters: 2_000), RunSegmentSample(seconds: 1_220, meters: 4_000)]
        // Le meilleur 2 km est la seconde moitié, qui part à la fin de l'arrêt.
        #expect(RunSegments.fastest(meters: 2_000, in: samples) == 500)
        // 3 km doivent traverser l'arrêt : 1 km de la première moitié (300 s) + l'arrêt + 2 km (500 s).
        #expect(RunSegments.fastest(meters: 3_000, in: samples) == 920)
    }

    @Test("sur une suite irrégulière, la fenêtre glissante égale la recherche exhaustive")
    func matchesABruteForceSearch() throws {
        var generator = SeededGenerator(seed: 42)
        var samples = [RunSegmentSample(seconds: 0, meters: 0)]
        for _ in 0..<400 {
            let last = samples[samples.count - 1]
            let step = Double.random(in: 0...30, using: &generator)
            let time = Double.random(in: 3...12, using: &generator)
            samples.append(RunSegmentSample(seconds: last.seconds + time, meters: last.meters + step))
        }
        for distance in [500.0, 1_234.5, 3_000] {
            let fast = try #require(RunSegments.fastest(meters: distance, in: samples))
            let brute = try #require(Self.bruteForce(meters: distance, in: samples))
            #expect(abs(fast - brute) < 1e-6)
        }
    }

    @Test("les instants d'un tracé suivent le temps du premier point et se recalent sur la distance de la séance")
    func samplesFromTrackPoints() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        // Trois points vers le nord, environ 111 m entre deux (0,001° de latitude).
        let points = (0..<3).map {
            RunTrackPoint(timestamp: start.addingTimeInterval(Double($0) * 30), latitude: 48.0 + Double($0) * 0.001,
                          longitude: 2.0, horizontalAccuracy: 5)
        }
        let raw = RunSegments.samples(from: points)
        #expect(raw.map(\.seconds) == [0, 30, 60])
        #expect(abs(raw[2].meters - 222.4) < 0.5)

        let scaled = RunSegments.samples(from: points, totalMeters: 250)
        #expect(scaled[2].meters == 250)
        #expect(abs(scaled[1].meters - 125) < 0.1)
        #expect(RunSegments.samples(from: []).isEmpty)
    }

    /// Chaque instant comme début et comme fin, avec interpolation : la référence lente.
    private static func bruteForce(meters distance: Double, in samples: [RunSegmentSample]) -> Double? {
        func time(at meters: Double, latest: Bool) -> Double? {
            let indices = latest ? Array(samples.indices.reversed()) : Array(samples.indices)
            for index in indices {
                let sample = samples[index]
                if latest, sample.meters <= meters {
                    guard index + 1 < samples.count else { return sample.seconds }
                    let next = samples[index + 1]
                    return sample.seconds + (meters - sample.meters) / (next.meters - sample.meters) * (next.seconds - sample.seconds)
                }
                if !latest, sample.meters >= meters {
                    guard index > 0 else { return sample.seconds }
                    let previous = samples[index - 1]
                    return previous.seconds + (meters - previous.meters) / (sample.meters - previous.meters)
                        * (sample.seconds - previous.seconds)
                }
            }
            return nil
        }
        var best: Double?
        for sample in samples {
            if let end = time(at: sample.meters + distance, latest: false) {
                best = min(best ?? .infinity, end - sample.seconds)
            }
            if sample.meters - distance >= 0, let start = time(at: sample.meters - distance, latest: true) {
                best = min(best ?? .infinity, sample.seconds - start)
            }
        }
        return best
    }
}

/// Un générateur reproductible (SplitMix64) : la fixture aléatoire est la même à chaque passage.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
