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

/// Les mesures d'une nuit, rattachées au jour de réveil (`day` = minuit local du jour de réveil).
public struct NightSample: Sendable, Equatable, Codable {
    public var day: Date
    public var sdnnMs: Double?
    public var restingHeartRate: Double?
    public var sleep: SleepSummary?

    public init(day: Date, sdnnMs: Double?, restingHeartRate: Double?, sleep: SleepSummary?) {
        self.day = day
        self.sdnnMs = sdnnMs
        self.restingHeartRate = restingHeartRate
        self.sleep = sleep
    }
}
