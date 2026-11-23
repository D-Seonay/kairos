import Foundation
import PulseDomain
import SwiftData

/// Le tracé d'une course Pulse terminée, synchronisé avec iCloud : points simplifiés, temps par km et dénivelé.
/// `id` est celui de la séance. Tout est optionnel ou a une valeur par défaut et rien n'est unique, comme l'exige CloudKit.
/// Les points, volumineux, sont rangés hors de la base (`externalStorage`).
@Model
public final class StoredRunTrack {
    public var id: UUID = UUID()
    @Attribute(.externalStorage) public var points: Data?
    public var splits: Data?
    public var elevationGainMeters: Double?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var deletedAt: Date?

    public init(_ track: RunTrack) {
        id = track.id
        createdAt = track.createdAt
        apply(track)
    }

    public func apply(_ track: RunTrack) {
        points = CodableColumn.encode(track.points)
        splits = CodableColumn.encode(track.splits)
        elevationGainMeters = track.elevationGainMeters
        updatedAt = track.updatedAt
    }

    /// Suppression logique : ne garde que la marque, jamais le tracé (donnée de localisation).
    public func markDeleted(at date: Date) {
        points = nil
        splits = nil
        elevationGainMeters = nil
        deletedAt = date
        updatedAt = date
    }

    public func toDomain() -> RunTrack {
        RunTrack(id: id, points: CodableColumn.decode([RunTrackPoint].self, from: points, default: []),
                 splits: CodableColumn.decode([RunSplit].self, from: splits, default: []),
                 elevationGainMeters: elevationGainMeters, createdAt: createdAt, updatedAt: updatedAt)
    }
}
