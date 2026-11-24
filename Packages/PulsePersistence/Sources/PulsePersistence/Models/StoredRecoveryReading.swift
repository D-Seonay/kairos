import Foundation
import PulseDomain
import SwiftData

/// Les dix valeurs brutes lues dans Apple Health pour un jour, gardées dans le magasin local : jamais synchronisées avec iCloud.
/// Une seule lecture par jour : `day` est une clé unique (le magasin local n'est pas soumis aux règles de CloudKit).
/// Les quatre minutes de phase (léger, paradoxal, sans phase, éveil) sont arrivées en V7.
@Model
public final class StoredRecoveryReading {
    @Attribute(.unique) public var day: Date = Date()
    public var sdnnMs: Double?
    public var sdnnBaselineMs: Double?
    public var restingHeartRate: Double?
    public var restingHeartRateBaseline: Double?
    public var asleepMinutes: Int?
    public var deepMinutes: Int?
    public var coreMinutes: Int?
    public var remMinutes: Int?
    public var unspecifiedMinutes: Int?
    public var awakeMinutes: Int?
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
        coreMinutes = recovery.coreMinutes
        remMinutes = recovery.remMinutes
        unspecifiedMinutes = recovery.unspecifiedMinutes
        awakeMinutes = recovery.awakeMinutes
        updatedAt = date
    }

    /// Vrai si les dix valeurs sont nulles : la ligne ne sert alors à rien.
    public var isEmpty: Bool {
        sdnnMs == nil && sdnnBaselineMs == nil && restingHeartRate == nil && restingHeartRateBaseline == nil
            && asleepMinutes == nil && deepMinutes == nil && coreMinutes == nil && remMinutes == nil
            && unspecifiedMinutes == nil && awakeMinutes == nil
    }

    /// Recopie les dix valeurs dans `recovery`.
    public func fill(_ recovery: inout DailyRecovery) {
        recovery.sdnnMs = sdnnMs
        recovery.sdnnBaselineMs = sdnnBaselineMs
        recovery.restingHeartRate = restingHeartRate
        recovery.restingHeartRateBaseline = restingHeartRateBaseline
        recovery.asleepMinutes = asleepMinutes
        recovery.deepMinutes = deepMinutes
        recovery.coreMinutes = coreMinutes
        recovery.remMinutes = remMinutes
        recovery.unspecifiedMinutes = unspecifiedMinutes
        recovery.awakeMinutes = awakeMinutes
    }
}
