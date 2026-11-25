import Foundation

/// Le meilleur temps d'une course sur une distance, mesuré sur un segment continu de son tracé.
public struct RunBestEffort: Sendable, Equatable, Codable {
    public var meters: Double
    public var seconds: Double

    public init(meters: Double, seconds: Double) {
        self.meters = meters
        self.seconds = seconds
    }
}

/// Les meilleurs segments d'une course Pulse (5 km, 10 km, semi), calculés une fois depuis son tracé. Une distance plus longue
/// que la course n'y figure pas ; une course plus courte que toutes garde une liste vide, pour ne pas être recalculée.
public struct RunBestEfforts: Sendable, Equatable, Codable, Identifiable {
    /// L'identifiant de la séance.
    public var id: UUID
    public var efforts: [RunBestEffort]

    public init(id: UUID, efforts: [RunBestEffort]) {
        self.id = id
        self.efforts = efforts
    }

    /// Le temps du meilleur segment de `meters`, s'il a été trouvé.
    public func seconds(for meters: Double) -> Double? {
        efforts.first { $0.meters == meters }?.seconds
    }
}

/// Le cache local des meilleurs segments, rempli à la fin d'une course et au passage du jour : les Stats le lisent sans relire
/// les tracés. Il ne contient que des durées, jamais de position, et ne va pas sur iCloud.
public protocol RunBestEffortStore: Sendable {
    /// Toutes les courses déjà calculées, par identifiant de séance.
    func all() async -> [UUID: RunBestEfforts]
    /// Ajoute ou remplace les courses données.
    func save(_ efforts: [RunBestEfforts]) async
    /// Oublie les courses données (séances supprimées).
    func remove(_ sessionIDs: Set<UUID>) async
}

/// Doublure en mémoire, pour les tests et les aperçus.
public actor InMemoryRunBestEffortStore: RunBestEffortStore {
    public private(set) var stored: [UUID: RunBestEfforts]
    /// Le nombre d'appels à `save`, pour vérifier qu'un cache plein n'est pas réécrit.
    public private(set) var saveCount = 0

    public init(_ efforts: [RunBestEfforts] = []) {
        stored = Dictionary(efforts.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    public func all() async -> [UUID: RunBestEfforts] {
        stored
    }

    public func save(_ efforts: [RunBestEfforts]) async {
        saveCount += 1
        for effort in efforts { stored[effort.id] = effort }
    }

    public func remove(_ sessionIDs: Set<UUID>) async {
        for id in sessionIDs { stored[id] = nil }
    }
}
