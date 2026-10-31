import Foundation

/// Résumé du sommeil d'une nuit. `deepMinutes` est nul quand la source ne fournit pas de phases.
public struct SleepSummary: Sendable, Equatable, Codable {
    public var asleepMinutes: Int
    public var deepMinutes: Int?

    public init(asleepMinutes: Int, deepMinutes: Int?) {
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
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
