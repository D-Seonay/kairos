import Foundation

/// Le score de récupération d'un jour, avec ses sous-scores et ses valeurs brutes (spec M2 §5.3).
public struct DailyRecovery: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var day: Date
    public var score: Double
    public var category: RecoveryCategory
    public var isEstimated: Bool
    public var hrvScore: Double?
    public var restingHeartRateScore: Double?
    public var sleepScore: Double?
    public var sdnnMs: Double?
    public var sdnnBaselineMs: Double?
    public var restingHeartRate: Double?
    public var restingHeartRateBaseline: Double?
    public var asleepMinutes: Int?
    public var deepMinutes: Int?
    /// Les minutes de léger, paradoxal, endormi sans phase et d'éveil de la nuit ; nulles sans phases (spec sommeil §6.2).
    public var coreMinutes: Int?
    public var remMinutes: Int?
    public var unspecifiedMinutes: Int?
    public var awakeMinutes: Int?
    public var missingFactors: [Factor]
    public var calibration: CalibrationState
    public var adjustments: [SessionAdjustment]
    public var frozenAt: Date?
    /// Vrai si l'utilisateur a gardé la séance prévue malgré l'ajustement proposé ; nul tant qu'il n'a pas choisi.
    public var originalSessionChosen: Bool?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), day: Date, score: Double, category: RecoveryCategory, isEstimated: Bool,
                hrvScore: Double? = nil, restingHeartRateScore: Double? = nil, sleepScore: Double? = nil,
                sdnnMs: Double? = nil, sdnnBaselineMs: Double? = nil, restingHeartRate: Double? = nil,
                restingHeartRateBaseline: Double? = nil, asleepMinutes: Int? = nil, deepMinutes: Int? = nil,
                coreMinutes: Int? = nil, remMinutes: Int? = nil, unspecifiedMinutes: Int? = nil, awakeMinutes: Int? = nil,
                missingFactors: [Factor] = [], calibration: CalibrationState, adjustments: [SessionAdjustment] = [],
                frozenAt: Date? = nil, originalSessionChosen: Bool? = nil, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.day = day
        self.score = score
        self.category = category
        self.isEstimated = isEstimated
        self.hrvScore = hrvScore
        self.restingHeartRateScore = restingHeartRateScore
        self.sleepScore = sleepScore
        self.sdnnMs = sdnnMs
        self.sdnnBaselineMs = sdnnBaselineMs
        self.restingHeartRate = restingHeartRate
        self.restingHeartRateBaseline = restingHeartRateBaseline
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
        self.coreMinutes = coreMinutes
        self.remMinutes = remMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
        self.awakeMinutes = awakeMinutes
        self.missingFactors = missingFactors
        self.calibration = calibration
        self.adjustments = adjustments
        self.frozenAt = frozenAt
        self.originalSessionChosen = originalSessionChosen
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
