import Foundation
import PulseDomain
import SwiftData

/// Le brouillon de la course en cours, local seulement : il porte les FC lues dans Apple Santé (frontière M8).
/// `id` est celui de la séance, clé unique (le magasin local n'est pas soumis aux règles de CloudKit).
/// Depuis la V9, la ligne n'est plus que l'en-tête : les points et les FC vont, par ajout, dans des `StoredRunDraftChunk`, et
/// chaque sauvegarde ne réécrit que l'en-tête et un petit paquet. Un brouillon d'avant (`isChunked` faux) garde tout dans
/// `payload` et se relit tel quel.
@Model
public final class StoredRunDraft {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Le `RunDraft` en JSON : entier avant la V9 ; sans ses points ni ses FC dans le format en paquets.
    public var payload: Data?
    public var updatedAt: Date = Date()
    /// Vrai pour le format en paquets (V9).
    public var isChunked: Bool = false
    /// Les points et les FC déjà écrits dans les paquets.
    public var storedPointCount: Int = 0
    public var storedHeartRateCount: Int = 0
    /// L'horodatage du dernier point écrit : un tracé qui ne le prolonge plus est réécrit en entier.
    public var lastPointAt: Date?
    /// Le prochain numéro de paquet.
    public var chunkCount: Int = 0

    public init(id: UUID) {
        self.id = id
    }

    /// Réécrit l'en-tête : le brouillon sans ses points ni ses FC.
    func writeHeader(_ draft: RunDraft) throws {
        var header = draft
        header.points = []
        header.heartRates = []
        payload = try JSONEncoder().encode(header)
        updatedAt = draft.updatedAt
        isChunked = true
    }

    /// L'en-tête (format en paquets) ou le brouillon entier (format d'avant la V9) ; `nil` s'il ne se relit plus.
    func decodedPayload() -> RunDraft? {
        payload.flatMap { try? JSONDecoder().decode(RunDraft.self, from: $0) }
    }
}

/// Un paquet de points et de FC ajoutés au brouillon `draftID` par une sauvegarde : jamais réécrit, relu dans l'ordre `order`.
@Model
public final class StoredRunDraftChunk {
    public var draftID: UUID = UUID()
    public var order: Int = 0
    public var points: Data?
    public var heartRates: Data?

    init(draftID: UUID, order: Int, points: ArraySlice<RunTrackPoint>, heartRates: ArraySlice<Double>) throws {
        self.draftID = draftID
        self.order = order
        self.points = points.isEmpty ? nil : try JSONEncoder().encode(Array(points))
        self.heartRates = heartRates.isEmpty ? nil : try JSONEncoder().encode(Array(heartRates))
    }

    func decodedPoints() throws -> [RunTrackPoint] {
        try points.map { try JSONDecoder().decode([RunTrackPoint].self, from: $0) } ?? []
    }

    func decodedHeartRates() throws -> [Double] {
        try heartRates.map { try JSONDecoder().decode([Double].self, from: $0) } ?? []
    }
}
