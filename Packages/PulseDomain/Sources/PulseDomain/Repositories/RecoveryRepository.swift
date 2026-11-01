import Foundation

public protocol RecoveryRepository: Sendable {
    func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery]
    /// Remplace l'enregistrement du même jour local, s'il existe.
    func save(_ recovery: DailyRecovery) async throws
    func checkIns(from: Date, to: Date) async throws -> [CheckIn]
    func save(_ checkIn: CheckIn) async throws
}
