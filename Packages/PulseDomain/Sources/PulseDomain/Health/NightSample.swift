import Foundation

/// Résumé du sommeil d'une nuit. Les minutes par phase sont nulles quand la source ne fournit pas de phases ; sinon profond,
/// léger, paradoxal et sans phase s'additionnent à `asleepMinutes`, et `awakeMinutes` compte l'éveil du bloc principal.
public struct SleepSummary: Sendable, Equatable, Codable {
    public var asleepMinutes: Int
    public var deepMinutes: Int?
    public var coreMinutes: Int?
    public var remMinutes: Int?
    public var unspecifiedMinutes: Int?
    public var awakeMinutes: Int?

    public init(asleepMinutes: Int, deepMinutes: Int?, coreMinutes: Int? = nil, remMinutes: Int? = nil,
                unspecifiedMinutes: Int? = nil, awakeMinutes: Int? = nil) {
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
        self.coreMinutes = coreMinutes
        self.remMinutes = remMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.awakeMinutes = awakeMinutes
    }
}

/// D'où vient la FC de repos d'une nuit.
public enum RestingHeartRateSource: String, Sendable, Equatable, Codable {
    /// La fréquence cardiaque la plus basse du bloc de sommeil principal (5e centile des mesures endormies).
    case overnightLowest
    /// L'échantillon « FC au repos » d'Apple Santé le plus proche du réveil, faute d'assez de mesures pendant le sommeil.
    case appleNearWake
}

/// Les mesures d'une nuit, rattachées au jour de réveil (`day` = minuit local du jour de réveil).
public struct NightSample: Sendable, Equatable, Codable {
    public var day: Date
    public var sdnnMs: Double?
    /// Le nombre de mesures SDNN moyennées dans `sdnnMs` ; `nil` quand il n'est pas connu (fixtures).
    public var sdnnSampleCount: Int?
    public var restingHeartRate: Double?
    /// D'où vient `restingHeartRate` ; `nil` quand il n'est pas connu (fixtures).
    public var restingHeartRateSource: RestingHeartRateSource?
    public var sleep: SleepSummary?

    public init(day: Date, sdnnMs: Double?, sdnnSampleCount: Int? = nil, restingHeartRate: Double?,
                restingHeartRateSource: RestingHeartRateSource? = nil, sleep: SleepSummary?) {
        self.day = day
        self.sdnnMs = sdnnMs
        self.sdnnSampleCount = sdnnSampleCount
        self.restingHeartRate = restingHeartRate
        self.restingHeartRateSource = restingHeartRateSource
        self.sleep = sleep
    }
}
