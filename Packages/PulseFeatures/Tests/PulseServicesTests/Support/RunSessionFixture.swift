import Foundation
import PulseDomain
import Synchronization
import Testing

@testable import PulseServices

/// Un brouillon qui délègue à `InMemoryRunDraftStore` et compte les écritures.
actor CountingRunDraftStore: RunDraftStore {
    private let inner: InMemoryRunDraftStore
    private(set) var saveCount = 0
    /// La prochaine écriture attend devant cette porte, avant d'écrire.
    private var heldAt: Gate?

    init(_ draft: RunDraft? = nil) {
        inner = InMemoryRunDraftStore(draft)
    }

    /// Suspend la prochaine écriture (une seule) jusqu'à `gate.open()`, pour rejouer un entrelacement précis.
    func holdNextSave(at gate: Gate) {
        heldAt = gate
    }

    func load() async throws -> RunDraft? {
        try await inner.load()
    }

    func save(_ draft: RunDraft) async throws {
        saveCount += 1
        if let gate = heldAt {
            heldAt = nil
            await gate.pass()
        }
        try await inner.save(draft)
    }

    func clear() async throws {
        try await inner.clear()
    }
}

/// Le rappel d'oubli, avec les appels gardés dans l'ordre.
actor OrderedRunReminderScheduler: RunReminderScheduling {
    enum Call: Equatable {
        case schedule(Date)
        case cancel
    }

    private(set) var calls: [Call] = []

    var scheduled: [Date] {
        calls.compactMap { if case .schedule(let date) = $0 { date } else { nil } }
    }

    func scheduleForgotten(at date: Date) async {
        calls.append(.schedule(date))
    }

    func cancelForgotten() async {
        calls.append(.cancel)
    }
}

/// Les tops de la tâche qui garde le brouillon à jour sans point : le test les donne un par un.
final class RunTickSource: Sendable {
    private let continuations = Mutex<[AsyncStream<Void>.Continuation]>([])

    func stream(every interval: TimeInterval) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        continuations.withLock { $0.append(continuation) }
        return stream
    }

    /// Un top au dernier flux ouvert.
    func tick() {
        _ = continuations.withLock { $0.last }?.yield()
    }
}

/// Le service de course et ses doublures, avec une horloge que le test avance point par point.
struct RunSessionFixture {
    static let start = TestClock.date("2026-11-24T07:00")

    /// Un texte qui garde l'événement entier, pour comparer ce qui a été annoncé.
    static let spokenText: @Sendable (RunAnnouncementEvent) -> String = { event in
        switch event {
        case .kilometer(let kilometer, let moving, let split): "km \(kilometer) \(moving) \(split)"
        case .halfTarget: "mi-objectif"
        case .targetReached: "objectif atteint"
        }
    }

    let clock = MutableClock(date: Self.start)
    let recorder: StubRunWorkoutRecorder
    let location: StubRunLocationTracker
    let announcer = StubRunAnnouncer()
    let activity = StubRunActivityController()
    let reminders = OrderedRunReminderScheduler()
    let drafts: CountingRunDraftStore
    let workouts: any WorkoutRepository
    let tracks = InMemoryRunTrackRepository()
    let profiles = InMemoryProfileRepository()
    let preferences = InMemoryRunPreferencesStore()
    let ticks = RunTickSource()
    let service: RunSessionService

    init(recorder: StubRunWorkoutRecorder = StubRunWorkoutRecorder(),
         location: StubRunLocationTracker = StubRunLocationTracker(), draft: RunDraft? = nil,
         workouts: any WorkoutRepository = InMemoryWorkoutRepository()) {
        self.recorder = recorder
        self.location = location
        self.workouts = workouts
        drafts = CountingRunDraftStore(draft)
        service = Self.makeService(recorder: recorder, location: location, announcer: announcer, activity: activity,
                                   reminders: reminders, drafts: drafts, workouts: workouts, tracks: tracks, profiles: profiles,
                                   preferences: preferences, ticks: ticks, clock: clock)
    }

    // swiftlint:disable:next function_parameter_count
    private static func makeService(recorder: StubRunWorkoutRecorder, location: StubRunLocationTracker, announcer: StubRunAnnouncer,
                                    activity: StubRunActivityController, reminders: OrderedRunReminderScheduler,
                                    drafts: CountingRunDraftStore, workouts: any WorkoutRepository,
                                    tracks: InMemoryRunTrackRepository, profiles: InMemoryProfileRepository,
                                    preferences: InMemoryRunPreferencesStore, ticks: RunTickSource,
                                    clock: MutableClock) -> RunSessionService {
        RunSessionService(
            recorder: recorder, location: location, announcer: announcer, activity: activity, reminders: reminders,
            drafts: drafts, workouts: workouts, tracks: tracks, profiles: profiles, preferences: preferences,
            spokenText: Self.spokenText, now: { clock.now }, calendar: TestClock.calendar,
            keepAliveTicks: { ticks.stream(every: $0) })
    }

    /// Le service d'un nouveau lancement de l'app, sur les mêmes magasins, après la mort du processus : la séance HealthKit
    /// n'est pas récupérée.
    func relaunched(recorder: StubRunWorkoutRecorder = StubRunWorkoutRecorder()) -> RunSessionService {
        Self.makeService(recorder: recorder, location: StubRunLocationTracker(), announcer: StubRunAnnouncer(),
                         activity: StubRunActivityController(), reminders: OrderedRunReminderScheduler(), drafts: drafts,
                         workouts: workouts, tracks: tracks, profiles: profiles, preferences: preferences,
                         ticks: RunTickSource(), clock: clock)
    }

    var start: Date { Self.start }

    /// Livre chaque point à l'heure de son horodatage et attend que le service l'ait traité.
    func push(_ points: [RunTrackPoint]) async {
        let handled = await service.handledPointCount
        for (index, point) in points.enumerated() {
            clock.set(date: point.timestamp)
            await location.push(point)
            await service.waitUntilHandled(points: handled + index + 1)
        }
    }

    /// Une fréquence cardiaque livrée par la séance HealthKit, attendue jusqu'à son traitement.
    func pushHeartRate(_ bpm: Double) async {
        let handled = await service.handledHeartRateCount
        await recorder.pushHeartRate(bpm)
        await service.waitUntilHandled(heartRates: handled + 1)
    }

    /// Avance l'horloge de `seconds`, donne un top à la tâche de maintien et attend son traitement.
    func tick(after seconds: TimeInterval) async {
        clock.set(date: clock.now.addingTimeInterval(seconds))
        let handled = await service.handledTickCount
        ticks.tick()
        await service.waitUntilHandled(ticks: handled + 1)
    }

    func advance(minutes: Double) {
        clock.set(date: clock.now.addingTimeInterval(minutes * 60))
    }

    /// Un brouillon de `meters` à 3 m/s, interrompu à son dernier point.
    static func interruptedDraft(meters: Double) -> RunDraft {
        let points = RunTraceFactory.clean(meters: meters, speed: 3, start: start)
        return RunDraft(sessionID: UUID(), launch: .free(), startedAt: start, points: points,
                        updatedAt: points.last?.timestamp ?? start)
    }
}
