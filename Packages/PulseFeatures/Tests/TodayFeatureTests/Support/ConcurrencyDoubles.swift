import Foundation
import PulseDomain
import PulseServices

/// Une porte : `pass()` suspend l'appelant jusqu'à `open()`, et le test peut attendre qu'un appelant soit arrivé devant elle.
actor Gate {
    private var isOpen = false
    private var arrivals = 0
    private var held: [CheckedContinuation<Void, Never>] = []
    private var watchers: [CheckedContinuation<Void, Never>] = []

    func pass() async {
        arrivals += 1
        let toWake = watchers
        watchers = []
        toWake.forEach { $0.resume() }
        guard !isOpen else { return }
        await withCheckedContinuation { held.append($0) }
    }

    func waitForArrival(_ count: Int = 1) async {
        while arrivals < count {
            await withCheckedContinuation { watchers.append($0) }
        }
    }

    func open() {
        isOpen = true
        let toWake = held
        held = []
        toWake.forEach { $0.resume() }
    }
}

/// Source Apple Santé qui compte les lectures de SDNN (une par lecture de nuits) et peut les suspendre derrière une porte.
actor CountingHealthSource: HealthSampleSource {
    private let inner: any HealthSampleSource
    private var gate: Gate?
    private(set) var nightReads = 0

    init(_ inner: any HealthSampleSource) {
        self.inner = inner
    }

    func hold(at gate: Gate) {
        self.gate = gate
    }

    func requestAuthorization() async throws {}

    func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        if signal == .sdnn {
            nightReads += 1
            if let gate { await gate.pass() }
        }
        return try await inner.changes(of: signal, since: anchor, from: start)
    }

    func profileHints() async throws -> HealthProfileHints {
        try await inner.profileHints()
    }
}

/// Dépôt de récupération qui compte les enregistrements de check-in et peut suspendre :
/// la prochaine lecture (rendue périmée une fois la porte ouverte) ou chaque enregistrement de check-in.
actor CountingRecoveryRepository: RecoveryRepository {
    private let inner: any RecoveryRepository
    private var nextReadGate: Gate?
    private var checkInSaveGate: Gate?
    private(set) var checkInSaves = 0

    init(_ inner: any RecoveryRepository) {
        self.inner = inner
    }

    /// Suspend une seule lecture, la prochaine, après l'avoir faite : elle rend ce qu'elle a vu avant les écritures du test.
    func holdNextRead(at gate: Gate) {
        nextReadGate = gate
    }

    func holdCheckInSaves(at gate: Gate) {
        checkInSaveGate = gate
    }

    func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery] {
        let result = try await inner.dailyRecoveries(from: from, to: to)
        if let gate = nextReadGate {
            nextReadGate = nil
            await gate.pass()
        }
        return result
    }

    func save(_ recovery: DailyRecovery) async throws {
        try await inner.save(recovery)
    }

    func checkIns(from: Date, to: Date) async throws -> [CheckIn] {
        try await inner.checkIns(from: from, to: to)
    }

    func save(_ checkIn: CheckIn) async throws {
        checkInSaves += 1
        if let gate = checkInSaveGate { await gate.pass() }
        try await inner.save(checkIn)
    }
}
