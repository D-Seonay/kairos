import Foundation

/// La séance en cours, écrite localement à chaque validation (spec M2 §5.4). `payload` : JSON défini en M4.
public struct ActiveSessionSnapshot: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    public var startedAt: Date
    public var updatedAt: Date
    public var payload: Data

    public init(id: UUID = UUID(), startedAt: Date, updatedAt: Date, payload: Data) {
        self.id = id
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
