import Foundation
import PulseDomain
import SwiftData

/// La séance en cours, locale seulement (spec M2 §5.4).
@Model
public final class StoredActiveSessionSnapshot {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var updatedAt: Date = Date()
    public var payload: Data?

    public init(_ snapshot: ActiveSessionSnapshot) {
        id = snapshot.id
        apply(snapshot)
    }

    public func apply(_ snapshot: ActiveSessionSnapshot) {
        startedAt = snapshot.startedAt
        updatedAt = snapshot.updatedAt
        payload = snapshot.payload
    }

    public func toDomain() -> ActiveSessionSnapshot {
        ActiveSessionSnapshot(id: id, startedAt: startedAt, updatedAt: updatedAt, payload: payload ?? Data())
    }
}
