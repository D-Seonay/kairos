import Foundation
import PulseDomain

/// Dépôt de mesures en mémoire, même sémantique que le dépôt SwiftData : `delete` est une suppression logique.
public actor InMemoryBodyMeasurementRepository: BodyMeasurementRepository {
    private var stored: [UUID: BodyMeasurement] = [:]
    private var deletedIDs: Set<UUID> = []

    public init(_ measurements: [BodyMeasurement] = []) {
        for measurement in measurements {
            stored[measurement.id] = measurement
        }
    }

    public func measurements(from: Date, to: Date) async throws -> [BodyMeasurement] {
        stored.values
            .filter { !deletedIDs.contains($0.id) && $0.date >= from && $0.date < to }
            .sorted { lhs, rhs in lhs.date != rhs.date ? lhs.date < rhs.date : lhs.createdAt < rhs.createdAt }
    }

    public func save(_ measurement: BodyMeasurement) async throws {
        deletedIDs.remove(measurement.id)
        stored[measurement.id] = measurement
    }

    /// Suppression logique : la mesure reste stockée mais n'est plus renvoyée.
    public func delete(id: UUID) async throws {
        if stored[id] != nil {
            deletedIDs.insert(id)
        }
    }
}
