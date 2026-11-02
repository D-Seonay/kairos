import Foundation
import PulseDomain

/// La séance en cours en mémoire : un seul snapshot, remplacé à chaque écriture.
public actor InMemoryActiveSessionStore: ActiveSessionStore {
    private var snapshot: ActiveSessionSnapshot?

    public init(_ snapshot: ActiveSessionSnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() async throws -> ActiveSessionSnapshot? {
        snapshot
    }

    public func save(_ snapshot: ActiveSessionSnapshot) async throws {
        self.snapshot = snapshot
    }

    public func clear() async throws {
        snapshot = nil
    }
}
