import Foundation
import PulseDomain

/// Tient à jour le cache des meilleurs segments des courses Pulse (5 km, 10 km, semi) : au passage du jour, chaque course Pulse
/// qui a un tracé et pas encore d'entrée est calculée une fois, et les séances disparues sont oubliées. Les Stats et le Profil
/// lisent ensuite le cache sans relire les tracés.
public struct RunBestEffortIndex: Sendable {
    private let workouts: any WorkoutRepository
    private let tracks: any RunTrackRepository
    private let store: any RunBestEffortStore

    public init(workouts: any WorkoutRepository, tracks: any RunTrackRepository, store: any RunBestEffortStore) {
        self.workouts = workouts
        self.tracks = tracks
        self.store = store
    }

    /// Calcule les courses manquantes et rend leur nombre. Une lecture qui échoue laisse le cache tel quel : la course est
    /// retentée au passage suivant.
    @discardableResult
    public func refresh() async -> Int {
        guard let sessions = try? await workouts.sessions(from: .distantPast, to: .distantFuture) else { return 0 }
        let runs = sessions.filter { $0.kind == .run && $0.source == .pulse && $0.status == .completed }
        let cached = await store.all()
        let gone = Set(cached.keys).subtracting(runs.map(\.id))
        if !gone.isEmpty { await store.remove(gone) }

        var computed: [RunBestEfforts] = []
        for run in runs where cached[run.id] == nil {
            // Sous 5 km, aucun segment à chercher : le tracé n'est pas lu.
            guard let meters = run.distanceMeters, meters >= Self.distances[0] else { continue }
            // Pas encore de tracé (iCloud l'apporte parfois après la séance) : rien n'est retenu, il sera relu.
            guard let track = try? await tracks.track(for: run.id), track.points.count >= 2 else { continue }
            computed.append(Self.efforts(of: track, session: run))
        }
        if !computed.isEmpty { await store.save(computed) }
        return computed.count
    }

    /// Les distances cherchées, de la plus courte à la plus longue.
    public static var distances: [Double] { RunDistance.allCases.map(\.rawValue) }

    /// Les meilleurs segments d'une suite d'instants ; une distance non couverte est omise.
    public static func efforts(sessionID: UUID, samples: [RunSegmentSample]) -> RunBestEfforts {
        RunBestEfforts(id: sessionID, efforts: distances.compactMap { meters in
            RunSegments.fastest(meters: meters, in: samples).map { RunBestEffort(meters: meters, seconds: $0) }
        })
    }

    /// Les meilleurs segments d'un tracé enregistré, recalé sur la distance de la séance. Le tracé ne garde pas les pauses : un
    /// segment qui en traverse une les compte, il est donc au pire plus lent que la réalité, jamais plus rapide.
    public static func efforts(of track: RunTrack, session: WorkoutSession) -> RunBestEfforts {
        efforts(sessionID: session.id, samples: RunSegments.samples(from: track.points, totalMeters: session.distanceMeters))
    }
}

/// Le cache dans `UserDefaults`, une seule clé en JSON : quelques durées par course, sans position. Seul le nom de la suite est
/// retenu (`UserDefaults` n'est pas `Sendable`) ; la suppression totale vide la suite en entier. Un acteur : deux écritures ne
/// se marchent pas dessus.
public actor UserDefaultsRunBestEffortStore: RunBestEffortStore {
    static let key = "pulse.runBestEfforts.v1"
    private let suiteName: String?

    public init(suiteName: String?) {
        self.suiteName = suiteName
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func all() async -> [UUID: RunBestEfforts] {
        load()
    }

    private func load() -> [UUID: RunBestEfforts] {
        guard let data = defaults.data(forKey: Self.key),
              let list = try? JSONDecoder().decode([RunBestEfforts].self, from: data) else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    public func save(_ efforts: [RunBestEfforts]) async {
        var stored = load()
        for effort in efforts { stored[effort.id] = effort }
        write(stored)
    }

    public func remove(_ sessionIDs: Set<UUID>) async {
        var stored = load()
        for id in sessionIDs { stored[id] = nil }
        write(stored)
    }

    private func write(_ stored: [UUID: RunBestEfforts]) {
        let list = stored.values.sorted { $0.id.uuidString < $1.id.uuidString }
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
