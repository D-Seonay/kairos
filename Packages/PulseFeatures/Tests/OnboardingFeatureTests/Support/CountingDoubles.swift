import Foundation
import PulseDomain
import PulseServices
import Synchronization

/// Un compteur d'appels partageable entre les tâches.
final class CallCounter: Sendable {
    private let value = Mutex(0)

    var count: Int { value.withLock { $0 } }

    func increment() {
        value.withLock { $0 += 1 }
    }
}

/// Un barrage : les lectures qui l'attendent restent suspendues jusqu'à `open()`.
actor Gate {
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(isOpen: Bool) {
        self.isOpen = isOpen
    }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

/// Une source Apple Santé qui compte les lectures de SDNN (une par lecture de nuits) et peut les retenir derrière un barrage.
struct CountingHealthSource: HealthSampleSource {
    let inner: any HealthSampleSource
    let reads = CallCounter()
    let gate: Gate

    init(inner: any HealthSampleSource, gateOpen: Bool = true) {
        self.inner = inner
        gate = Gate(isOpen: gateOpen)
    }

    func requestAuthorization() async throws {
        try await inner.requestAuthorization()
    }

    func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        if signal == .sdnn {
            reads.increment()
            await gate.wait()
        }
        return try await inner.changes(of: signal, since: anchor, from: start)
    }

    func profileHints() async throws -> HealthProfileHints {
        try await inner.profileHints()
    }
}

/// Un dépôt de récupération qui compte les check-in enregistrés.
struct CountingRecoveryRepository: RecoveryRepository {
    let inner: any RecoveryRepository
    let checkInSaves = CallCounter()

    func dailyRecoveries(from: Date, to: Date) async throws -> [DailyRecovery] {
        try await inner.dailyRecoveries(from: from, to: to)
    }

    func save(_ recovery: DailyRecovery) async throws {
        try await inner.save(recovery)
    }

    func checkIns(from: Date, to: Date) async throws -> [CheckIn] {
        try await inner.checkIns(from: from, to: to)
    }

    func save(_ checkIn: CheckIn) async throws {
        checkInSaves.increment()
        try await inner.save(checkIn)
    }
}

/// Un dépôt de programmes dont la suppression et la lecture échouent à la demande.
actor FlakyProgramRepository: ProgramRepository {
    struct DeleteFailure: Error {}
    struct ReadFailure: Error {}

    private let inner = InMemoryProgramRepository()
    private var failsOnDelete = false
    private var failsOnRead = false

    func setFailsOnDelete(_ value: Bool) {
        failsOnDelete = value
    }

    func setFailsOnRead(_ value: Bool) {
        failsOnRead = value
    }

    func programs(includeArchived: Bool) async throws -> [Program] {
        if failsOnRead { throw ReadFailure() }
        return try await inner.programs(includeArchived: includeArchived)
    }

    func program(id: UUID) async throws -> Program? {
        if failsOnRead { throw ReadFailure() }
        return try await inner.program(id: id)
    }

    func save(_ program: Program) async throws {
        try await inner.save(program)
    }

    func delete(id: UUID) async throws {
        if failsOnDelete { throw DeleteFailure() }
        try await inner.delete(id: id)
    }
}
