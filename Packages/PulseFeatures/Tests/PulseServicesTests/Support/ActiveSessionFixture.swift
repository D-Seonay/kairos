import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Un service de séance active sur des dépôts en mémoire, avec une horloge qu'on avance, partagé par les suites de la séance
/// active. L'horloge part du lundi 2 novembre 2026 à 8 h.
struct ActiveSessionFixture {
    let clock = MutableClock("2026-11-02T08:00")
    let store: any ActiveSessionStore
    let memoryStore = InMemoryActiveSessionStore()
    let workouts = InMemoryWorkoutRepository()
    let profiles = InMemoryProfileRepository()
    let settings = InMemoryExerciseSettingsRepository()
    let userExercises = InMemoryUserExerciseRepository()
    let notifier = StubRestTimerNotifier()
    let activity = StubSessionActivityController()

    init(store: (any ActiveSessionStore)? = nil) {
        self.store = store ?? memoryStore
    }

    /// Un service neuf sur les mêmes dépôts : ce que l'app retrouve après une relance.
    func makeService() -> ActiveSessionService {
        let clock = clock
        let records = RecordsService(workouts: workouts, records: InMemoryPersonalRecordRepository(), userExercises: userExercises,
                                     library: .bundled, now: { clock.now })
        return ActiveSessionService(store: store, workouts: workouts, profiles: profiles, settings: settings,
                                    userExercises: userExercises, records: records, library: .bundled, restNotifier: notifier,
                                    activity: activity, calendar: TestClock.calendar, now: { clock.now })
    }

    /// Une séance terminée la semaine dernière avec ces séries, dans l'ordre.
    func seedHistory(_ sets: [WorkoutSet]) async throws {
        let ordered = sets.enumerated().map { index, set in
            var set = set
            set.order = index
            return set
        }
        let day = TestClock.date("2026-10-26T08:00")
        try await workouts.save(WorkoutSession(startedAt: day, kind: .strength, source: .pulse, status: .completed, title: "Push",
                                               sets: ordered, createdAt: day, updatedAt: day))
    }

    func setRestNotifications(enabled: Bool) async throws {
        try await profiles.save(UserProfile(restTimerNotificationEnabled: enabled, createdAt: .t0, updatedAt: .t0))
    }

    /// La séance enregistrée, relue depuis le snapshot.
    func stored() async throws -> LiveSession? {
        guard let snapshot = try await store.load() else { return nil }
        return LiveSession.decode(snapshot.payload)
    }

    /// Bench (repos 120 s, historique 60 × 12, 70 × 5, 70 × 5) puis pec deck (60 s, sans historique), un jour de fatigue :
    /// bench en 2 séries 60 × 12 et 70 × 5, repos 165 s.
    static let pushLaunch = LiveFixtures.launch(
        LiveFixtures.day([LiveFixtures.exercise(LiveFixtures.bench, order: 0, rpe: 8, rest: 120),
                          LiveFixtures.exercise(LiveFixtures.pecDeck, order: 1, rpe: 7, rest: 60)]),
        .moderateFatigue)

    /// Un service démarré sur `pushLaunch`, avec l'historique du bench.
    func startPush() async throws -> (ActiveSessionService, LiveSession) {
        try await seedHistory(LiveFixtures.rampingBench)
        let service = makeService()
        return (service, try await service.start(Self.pushLaunch))
    }
}

/// Un snapshot dont on peut faire échouer l'écriture.
actor FailingActiveSessionStore: ActiveSessionStore {
    private let inner = InMemoryActiveSessionStore()
    private var failsOnSave = false

    struct Failure: Error {}

    func setFailsOnSave(_ value: Bool) {
        failsOnSave = value
    }

    func load() async throws -> ActiveSessionSnapshot? {
        try await inner.load()
    }

    func save(_ snapshot: ActiveSessionSnapshot) async throws {
        if failsOnSave { throw Failure() }
        try await inner.save(snapshot)
    }

    func clear() async throws {
        try await inner.clear()
    }
}
