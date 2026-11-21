import Foundation
import PulseDomain
import SwiftData

/// Les six valeurs brutes lues dans Apple Health pour un jour, gardées dans le magasin local : jamais synchronisées avec iCloud.
@Model
public final class StoredRecoveryReading {
    public var day: Date = Date()
    public var sdnnMs: Double?
    public var sdnnBaselineMs: Double?
    public var restingHeartRate: Double?
    public var restingHeartRateBaseline: Double?
    public var asleepMinutes: Int?
    public var deepMinutes: Int?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(day: Date, from recovery: DailyRecovery, at date: Date) {
        self.day = day
        createdAt = date
        apply(recovery, at: date)
    }

    public func apply(_ recovery: DailyRecovery, at date: Date) {
        sdnnMs = recovery.sdnnMs
        sdnnBaselineMs = recovery.sdnnBaselineMs
        restingHeartRate = recovery.restingHeartRate
        restingHeartRateBaseline = recovery.restingHeartRateBaseline
        asleepMinutes = recovery.asleepMinutes
        deepMinutes = recovery.deepMinutes
        updatedAt = date
    }

    /// Vrai si les six valeurs sont nulles : la ligne ne sert alors à rien.
    public var isEmpty: Bool {
        sdnnMs == nil && sdnnBaselineMs == nil && restingHeartRate == nil && restingHeartRateBaseline == nil
            && asleepMinutes == nil && deepMinutes == nil
    }

    /// Recopie les six valeurs dans `recovery`.
    public func fill(_ recovery: inout DailyRecovery) {
        recovery.sdnnMs = sdnnMs
        recovery.sdnnBaselineMs = sdnnBaselineMs
        recovery.restingHeartRate = restingHeartRate
        recovery.restingHeartRateBaseline = restingHeartRateBaseline
        recovery.asleepMinutes = asleepMinutes
        recovery.deepMinutes = deepMinutes
    }
}
