import Foundation

/// Une plage d'une seule phase dans une nuit reconstituée : éveillé, endormi sans phase, léger, profond ou paradoxal.
public struct SleepSegment: Sendable, Equatable, Codable {
    public var start: Date
    public var end: Date
    public var stage: SleepStage

    public init(start: Date, end: Date, stage: SleepStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }
}

/// Un bloc de sommeil compté dans la nuit mais séparé du bloc principal (une sieste en fin d'après-midi, par exemple).
public struct SleepBlock: Sendable, Equatable, Codable {
    public var start: Date
    public var end: Date
    public var asleepMinutes: Int

    public init(start: Date, end: Date, asleepMinutes: Int) {
        self.start = start
        self.end = end
        self.asleepMinutes = asleepMinutes
    }
}

/// Une nuit reconstituée phase par phase, rattachée au jour de réveil comme `NightSample`.
///
/// Les minutes endormies (`asleepMinutes`, et les quatre phases qui s'y additionnent) comptent tous les blocs de la nuit,
/// comme le score ; l'endormissement, le réveil, les segments, l'éveil et les réveils ne portent que sur le bloc principal.
public struct NightSleep: Sendable, Equatable, Codable {
    /// Minuit local du jour de réveil.
    public var day: Date
    public var fellAsleep: Date
    public var wokeUp: Date
    /// Les segments du bloc principal, triés et sans chevauchement ; un trou sans donnée n'a pas de segment.
    public var segments: [SleepSegment]
    public var otherBlocks: [SleepBlock]
    public var asleepMinutes: Int
    public var deepMinutes: Int
    public var coreMinutes: Int
    public var remMinutes: Int
    public var unspecifiedMinutes: Int
    public var awakeMinutes: Int
    public var awakenings: Int
    /// Vrai si la source donne au moins une phase (léger, profond ou paradoxal).
    public var hasStages: Bool

    public init(day: Date, fellAsleep: Date, wokeUp: Date, segments: [SleepSegment], otherBlocks: [SleepBlock], asleepMinutes: Int,
                deepMinutes: Int, coreMinutes: Int, remMinutes: Int, unspecifiedMinutes: Int, awakeMinutes: Int, awakenings: Int,
                hasStages: Bool) {
        self.day = day
        self.fellAsleep = fellAsleep
        self.wokeUp = wokeUp
        self.segments = segments
        self.otherBlocks = otherBlocks
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
        self.coreMinutes = coreMinutes
        self.remMinutes = remMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.awakeMinutes = awakeMinutes
        self.awakenings = awakenings
        self.hasStages = hasStages
    }
}
