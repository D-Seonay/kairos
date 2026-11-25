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

    /// Au-delà de ce délai après la course, un tracé absent n'arrivera plus d'iCloud : la course est retenue comme traitée.
    public static let missingTrackGrace: TimeInterval = 3 * 86_400

    /// Calcule les courses manquantes et rend leur nombre. Une lecture qui échoue laisse le cache tel quel : la course est
    /// retentée au passage suivant. Une course sans tracé utilisable est retenue avec une liste vide (ses records restent à
    /// l'allure moyenne), pour ne pas être relue à chaque passage.
    @discardableResult
    public func refresh(now: Date) async -> Int {
        // Le cache est lu avant les séances : une course finie entre les deux lectures, déjà rangée dans le cache avec ses points
        // bruts, n'est pas prise pour une séance disparue.
        let cached = await store.all()
        guard let sessions = try? await workouts.sessions(from: .distantPast, to: .distantFuture) else { return 0 }
        let runs = sessions.filter { $0.kind == .run && $0.source == .pulse && $0.status == .completed }
        let gone = Set(cached.keys).subtracting(runs.map(\.id))
        if !gone.isEmpty { await store.remove(gone) }

        var computed: [RunBestEfforts] = []
        for run in runs where cached[run.id] == nil {
            // Sous 5 km, aucun segment à chercher : le tracé n'est pas lu.
            guard let meters = run.distanceMeters, meters >= Self.distances[0] else { continue }
            let fetched: RunTrack?
            do {
                fetched = try await tracks.track(for: run.id)
            } catch {
                continue
            }
            if let track = fetched, track.points.count >= 2 {
                computed.append(Self.efforts(of: track, session: run))
            } else if fetched != nil || now.timeIntervalSince(run.endedAt ?? run.startedAt) > Self.missingTrackGrace {
                // Un tracé sans assez de points, ou absent trop longtemps après la course : rien à chercher, une fois pour toutes.
                computed.append(RunBestEfforts(id: run.id, efforts: []))
            }
            // Sinon le tracé n'est pas encore arrivé d'iCloud : la course est relue au passage suivant.
        }
        // Une course finie pendant le passage a pu ranger entre-temps ses segments, plus justes (points bruts) : ils restent.
        let latest = computed.isEmpty ? [:] : await store.all()
        computed.removeAll { latest[$0.id] != nil }
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

    /// Les meilleurs segments d'un tracé enregistré. Le tracé ne garde pas les pauses : un segment qui en traverse une compte
    /// leur durée, et la distance parcourue pendant une pause est écartée (pas trop rapide pour une course, tracé raccourci à la
    /// distance de la séance). Le segment est donc au pire plus lent que la réalité, jamais plus rapide.
    public static func efforts(of track: RunTrack, session: WorkoutSession) -> RunBestEfforts {
        efforts(sessionID: session.id, samples: RunSegments.samples(from: track.points, totalMeters: session.distanceMeters,
                                                                     maxSpeed: RunTrackBuilder.maxSpeed))
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
