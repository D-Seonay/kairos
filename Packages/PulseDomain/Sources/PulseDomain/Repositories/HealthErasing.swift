import Foundation

/// Effacement de ce que Pulse a écrit dans Apple Santé. Implémenté par `PulseHealth` en M4 ; stub d'ici là.
public protocol HealthErasing: Sendable {
    func deleteAllSamplesWrittenByPulse() async throws
}

/// Doublure qui compte les appels et lance `error` si fourni.
public final class StubHealthEraser: HealthErasing, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private let error: (any Error)?

    public init(error: (any Error)? = nil) {
        self.error = error
    }

    public var callCount: Int {
        lock.withLock { count }
    }

    public func deleteAllSamplesWrittenByPulse() async throws {
        lock.withLock { count += 1 }
        if let error { throw error }
    }
}
