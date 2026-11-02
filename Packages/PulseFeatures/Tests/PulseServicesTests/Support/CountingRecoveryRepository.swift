import Foundation
import PulseDomain
import PulseServices

/// Dépôt de récupération en mémoire qui compte ses appels et ses enregistrements de score,
/// et peut suspendre chacun de ces enregistrements derrière une porte.
actor CountingRecoveryRepository: RecoveryRepository {
    private let inner: InMemoryRecoveryRepository
    private var recoverySaveGate: Gate?
    /// Tous les appels, lectures comprises.
    private(set) var calls = 0
    private(set) var recoverySaves = 0

    init(calendar: Calendar) {
        inner = InMemoryRecoveryRepository(calendar: calendar)
    }

    func holdRecoverySaves(at gate: Gate) {
        recoverySaveGate = gate
    }

    func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery] {
        calls += 1
        return try await inner.dailyRecoveries(from: from, to: to)
    }

    func save(_ recovery: DailyRecovery) async throws {
        calls += 1
        recoverySaves += 1
        if let gate = recoverySaveGate { await gate.pass() }
        try await inner.save(recovery)
    }

    func checkIns(from: Date, to: Date) async throws -> [CheckIn] {
        calls += 1
        return try await inner.checkIns(from: from, to: to)
    }

    func save(_ checkIn: CheckIn) async throws {
        calls += 1
        try await inner.save(checkIn)
    }
}
