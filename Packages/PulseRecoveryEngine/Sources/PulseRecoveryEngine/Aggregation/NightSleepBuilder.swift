import Foundation
import PulseDomain

/// Reconstitue une nuit phase par phase depuis les intervalles bruts d'Apple Santé (spec sommeil §6.1).
///
/// Le rattachement est celui de `NightAggregator` (`NightWindow`) : les minutes endormies et profondes égalent celles du score.
/// Quand deux sources se chevauchent, chaque tranche prend la phase la plus prioritaire qui la couvre :
/// profond > paradoxal > léger > endormi sans phase > éveillé.
public struct NightSleepBuilder: Sendable {
    /// La durée minimale d'une plage d'éveil pour compter comme un réveil.
    public static let minimumAwakening: TimeInterval = 120
    /// Au-delà de cet écart sans sommeil, deux plages endormies appartiennent à deux blocs distincts.
    public static let blockGap: TimeInterval = 3600

    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// La nuit dont le réveil tombe le jour `day` (minuit local), ou `nil` sans aucun intervalle endormi rattaché.
    public func night(for day: Date, sleep: [SleepInterval]) -> NightSleep? {
        let asleep = NightWindow.retainedAsleep(for: day, in: sleep, calendar: calendar)
        guard let spanStart = asleep.map(\.start).min(), let spanEnd = asleep.map(\.end).max() else { return nil }
        let awake = sleep.compactMap { interval -> SleepInterval? in
            guard interval.stage == .awake else { return nil }
            let start = max(interval.start, spanStart)
            let end = min(interval.end, spanEnd)
            return end > start ? SleepInterval(start: start, end: end, stage: .awake) : nil
        }
        let segments = Self.resolve(asleep + awake)
        let blocks = Self.blocks(of: segments)
        guard let mainIndex = Self.mainBlockIndex(blocks), let first = blocks[mainIndex].first,
              let last = blocks[mainIndex].last else { return nil }
        let main = blocks[mainIndex]
        let minutes = Self.stageMinutes(blocks.flatMap { $0 })
        let mainAwake = main.filter { $0.stage == .awake }
        let others = blocks.indices.filter { $0 != mainIndex }.compactMap { index -> SleepBlock? in
            guard let start = blocks[index].first?.start, let end = blocks[index].last?.end else { return nil }
            return SleepBlock(start: start, end: end, asleepMinutes: Self.rounded(Self.asleepSeconds(blocks[index])))
        }
        return NightSleep(
            day: day, fellAsleep: first.start, wokeUp: last.end, segments: main, otherBlocks: others,
            asleepMinutes: minutes.asleep, deepMinutes: minutes.deep, coreMinutes: minutes.core, remMinutes: minutes.rem,
            unspecifiedMinutes: minutes.unspecified,
            awakeMinutes: Self.rounded(mainAwake.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }),
            awakenings: mainAwake.filter { $0.end.timeIntervalSince($0.start) >= Self.minimumAwakening }.count,
            hasStages: segments.contains { [.core, .deep, .rem].contains($0.stage) })
    }

    // MARK: - Tranches

    private static func priority(_ stage: SleepStage) -> Int {
        switch stage {
        case .deep: 5
        case .rem: 4
        case .core: 3
        case .asleepUnspecified: 2
        case .awake: 1
        case .inBed: 0
        }
    }

    /// Découpe aux bornes de tous les intervalles ; chaque tranche prend la phase la plus prioritaire qui la couvre, puis les
    /// tranches contiguës de même phase fusionnent. Une tranche que rien ne couvre est un trou sans donnée : pas de segment.
    private static func resolve(_ intervals: [SleepInterval]) -> [SleepSegment] {
        let bounds = Array(Set(intervals.flatMap { [$0.start, $0.end] })).sorted()
        var segments: [SleepSegment] = []
        for (lower, upper) in zip(bounds, bounds.dropFirst()) {
            let covering = intervals.filter { $0.start <= lower && $0.end >= upper }
            guard let stage = covering.map(\.stage).max(by: { priority($0) < priority($1) }) else { continue }
            if let previous = segments.last, previous.stage == stage, previous.end == lower {
                segments[segments.count - 1].end = upper
            } else {
                segments.append(SleepSegment(start: lower, end: upper, stage: stage))
            }
        }
        return segments
    }

    // MARK: - Blocs

    /// Regroupe les segments en blocs séparés par plus de `blockGap` sans sommeil. Chaque bloc commence et finit par un segment
    /// endormi ; l'éveil hors de tout bloc est jeté.
    private static func blocks(of segments: [SleepSegment]) -> [[SleepSegment]] {
        var blocks: [[SleepSegment]] = []
        var current: [SleepSegment] = []
        var pendingAwake: [SleepSegment] = []
        for segment in segments {
            if segment.stage == .awake {
                if !current.isEmpty { pendingAwake.append(segment) }
                continue
            }
            if let lastAsleep = current.last, segment.start.timeIntervalSince(lastAsleep.end) > blockGap {
                blocks.append(current)
                current = []
                pendingAwake = []
            }
            current += pendingAwake
            pendingAwake = []
            current.append(segment)
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks
    }

    /// Le bloc qui a le plus de secondes endormies ; à égalité, le plus tardif (le plus proche du réveil).
    private static func mainBlockIndex(_ blocks: [[SleepSegment]]) -> Int? {
        var best: Int?
        for index in blocks.indices {
            if let current = best, asleepSeconds(blocks[index]) < asleepSeconds(blocks[current]) { continue }
            best = index
        }
        return best
    }

    private static func asleepSeconds(_ segments: [SleepSegment]) -> TimeInterval {
        segments.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }

    // MARK: - Minutes

    private struct StageMinutes {
        var asleep = 0
        var deep = 0
        var core = 0
        var rem = 0
        var unspecified = 0
    }

    /// Les minutes de chaque phase endormie ; le total est arrondi une fois, comme dans `NightAggregator`. Le profond n'est
    /// jamais ajusté : le reste d'arrondi va au léger, sinon au sans-phase, sinon au paradoxal, pour que la somme égale le total.
    private static func stageMinutes(_ segments: [SleepSegment]) -> StageMinutes {
        func seconds(_ stage: SleepStage) -> TimeInterval {
            segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        }
        var minutes = StageMinutes()
        minutes.asleep = rounded(asleepSeconds(segments))
        minutes.deep = rounded(seconds(.deep))
        minutes.rem = rounded(seconds(.rem))
        minutes.unspecified = rounded(seconds(.asleepUnspecified))
        minutes.core = rounded(seconds(.core))
        let residue = minutes.asleep - (minutes.deep + minutes.core + minutes.rem + minutes.unspecified)
        if seconds(.core) > 0 {
            minutes.core = max(0, minutes.core + residue)
        } else if seconds(.asleepUnspecified) > 0 {
            minutes.unspecified = max(0, minutes.unspecified + residue)
        } else if seconds(.rem) > 0 {
            minutes.rem = max(0, minutes.rem + residue)
        }
        return minutes
    }

    private static func rounded(_ seconds: TimeInterval) -> Int {
        Int((seconds / 60).rounded())
    }
}
