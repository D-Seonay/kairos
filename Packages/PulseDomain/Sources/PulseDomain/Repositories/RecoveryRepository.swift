import Foundation

public protocol RecoveryRepository: Sendable {
    func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery]
    /// Remplace l'enregistrement du même jour local, s'il existe.
    func save(_ recovery: DailyRecovery) async throws
    func checkIns(from: Date, to: Date) async throws -> [CheckIn]
    func save(_ checkIn: CheckIn) async throws
    /// Ajoute les minutes de phase des nuits du cache aux valeurs brutes enregistrées avant qu'elles existent : seulement si la
    /// nuit a des phases, que l'enregistrement du jour n'en a pas et que son total endormi et son profond égalent encore ceux de
    /// la nuit (les phases s'additionnent alors au total enregistré). Le score et les autres valeurs ne bougent pas.
    func backfillSleepStages(_ nights: [NightSample]) async throws
}
