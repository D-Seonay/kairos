import Foundation
import PulseDomain
import SwiftData

@Model
public final class StoredDailyRecovery {
    public var id: UUID = UUID()
    public var day: Date = Date()
    public var score: Double = 0
    public var category: String = RecoveryCategory.normal.rawValue
    public var isEstimated: Bool = false
    public var hrvScore: Double?
    public var restingHeartRateScore: Double?
    public var sleepScore: Double?
    public var sdnnMs: Double?
    public var sdnnBaselineMs: Double?
    public var restingHeartRate: Double?
    public var restingHeartRateBaseline: Double?
    public var asleepMinutes: Int?
    public var deepMinutes: Int?
    public var missingFactors: Data?
    public var calibration: Data?
    public var adjustments: Data?
    public var frozenAt: Date?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ recovery: DailyRecovery) {
        id = recovery.id
        createdAt = recovery.createdAt
        apply(recovery)
    }

    public func apply(_ recovery: DailyRecovery) {
        day = recovery.day
        score = recovery.score
        category = recovery.category.rawValue
        isEstimated = recovery.isEstimated
        hrvScore = recovery.hrvScore
        restingHeartRateScore = recovery.restingHeartRateScore
        sleepScore = recovery.sleepScore
        sdnnMs = recovery.sdnnMs
        sdnnBaselineMs = recovery.sdnnBaselineMs
        restingHeartRate = recovery.restingHeartRate
        restingHeartRateBaseline = recovery.restingHeartRateBaseline
        asleepMinutes = recovery.asleepMinutes
        deepMinutes = recovery.deepMinutes
        missingFactors = CodableColumn.encode(recovery.missingFactors)
        calibration = CodableColumn.encode(recovery.calibration)
        adjustments = CodableColumn.encode(recovery.adjustments)
        frozenAt = recovery.frozenAt
        updatedAt = recovery.updatedAt
    }

    public func toDomain() -> DailyRecovery {
        DailyRecovery(id: id, day: day, score: score, category: .stored(category, default: .normal), isEstimated: isEstimated,
                      hrvScore: hrvScore, restingHeartRateScore: restingHeartRateScore, sleepScore: sleepScore, sdnnMs: sdnnMs,
                      sdnnBaselineMs: sdnnBaselineMs, restingHeartRate: restingHeartRate,
                      restingHeartRateBaseline: restingHeartRateBaseline,
                      asleepMinutes: asleepMinutes, deepMinutes: deepMinutes,
                      missingFactors: CodableColumn.decode([Factor].self, from: missingFactors, default: []),
                      calibration: CodableColumn.decode(CalibrationState.self, from: calibration, default: .ready),
                      adjustments: CodableColumn.decode([SessionAdjustment].self, from: adjustments, default: []),
                      frozenAt: frozenAt, createdAt: createdAt, updatedAt: updatedAt)
    }
}
