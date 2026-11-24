import Foundation
import PulseDomain

/// Mène une course : séance HealthKit, points GPS, distance et temps par km, annonces vocales, Live Activity, brouillon de reprise,
/// rappel d'oubli et enregistrement final (spec V2a §4 et §5).
///
/// L'horloge injectée décide des cadences (brouillon, Live Activity, oubli) ; les horodatages des points nourrissent le calcul de la
/// distance. Les points et la FC arrivent par des flux consommés dans des tâches que le service garde et annule à la fin.
public actor RunSessionService {
    /// Sans déplacement hors pause pendant ce temps, la course est sans doute oubliée.
    public static let forgottenAfter: TimeInterval = 30 * 60
    /// Écart minimal entre deux écritures du brouillon au fil des points.
    public static let draftInterval: TimeInterval = 10
    /// Écart minimal entre deux mises à jour de la Live Activity au fil des points, hors passage d'un km.
    public static let activityInterval: TimeInterval = 15
    /// Le rappel d'oubli n'est reprogrammé que si le dernier déplacement a avancé de plus que cela.
    static let reminderStep: TimeInterval = 60

    let recorder: any RunWorkoutRecording
    let location: any RunLocationTracking
    let announcer: any RunAnnouncing
    let activity: any RunActivityControlling
    let reminders: any RunReminderScheduling
    let drafts: any RunDraftStore
    let workouts: any WorkoutRepository
    let tracks: any RunTrackRepository
    let profiles: any ProfileRepository
    let preferences: any RunPreferencesStore
    let spokenText: @Sendable (RunAnnouncementEvent) -> String
    let now: @Sendable () -> Date
    let calendar: Calendar
    let keepAliveTicks: @Sendable (TimeInterval) -> AsyncStream<Void>

    /// La course en cours dans ce processus.
    var run: ActiveRun?
    /// Vrai pendant un départ ou un rattachement, que les autres appels n'interrompent pas.
    var isTransitioning = false
    var pointTask: Task<Void, Never>?
    var heartRateTask: Task<Void, Never>?
    var keepAliveTask: Task<Void, Never>?
    var previewTask: Task<Void, Never>?
    var previewContinuation: AsyncStream<RunGPSQuality>.Continuation?
    /// Avance à chaque arrêt de l'aperçu : un aperçu qui attendait le démarrage de la localisation sait qu'il a été arrêté.
    var previewGeneration = 0
    var snapshotContinuation: AsyncStream<RunSnapshot>.Continuation?

    /// Points, FC et tops traités depuis la création, pour que les tests attendent leur traitement sans délai arbitraire.
    var handledPointCount = 0
    var handledHeartRateCount = 0
    var handledTickCount = 0
    private var waiters: [(waiter: HandledWaiter, continuation: CheckedContinuation<Void, Never>)] = []

    public init(recorder: any RunWorkoutRecording, location: any RunLocationTracking, announcer: any RunAnnouncing,
                activity: any RunActivityControlling, reminders: any RunReminderScheduling, drafts: any RunDraftStore,
                workouts: any WorkoutRepository, tracks: any RunTrackRepository, profiles: any ProfileRepository,
                preferences: any RunPreferencesStore, spokenText: @escaping @Sendable (RunAnnouncementEvent) -> String,
                now: @escaping @Sendable () -> Date, calendar: Calendar,
                keepAliveTicks: @escaping @Sendable (TimeInterval) -> AsyncStream<Void> = RunSessionService.periodicTicks(every:)) {
        self.recorder = recorder
        self.location = location
        self.announcer = announcer
        self.activity = activity
        self.reminders = reminders
        self.drafts = drafts
        self.workouts = workouts
        self.tracks = tracks
        self.profiles = profiles
        self.preferences = preferences
        self.spokenText = spokenText
        self.now = now
        self.calendar = calendar
        self.keepAliveTicks = keepAliveTicks
    }

    /// Un top toutes les `interval` secondes, jusqu'à l'abandon du flux.
    public static func periodicTicks(every interval: TimeInterval) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Écran de course

    /// Un seul abonné, l'écran de course : un nouvel appel termine le flux précédent. Le flux rend tout de suite l'état courant,
    /// puis un état à chaque point, FC, pause ou reprise ; il se termine avec la course.
    public func snapshots() -> AsyncStream<RunSnapshot> {
        snapshotContinuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: RunSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        snapshotContinuation = continuation
        if let snapshot = current() { continuation.yield(snapshot) }
        return stream
    }

    public func current() -> RunSnapshot? {
        run.map { snapshot(of: $0, at: now()) }
    }

    // MARK: Écran de départ

    /// Écran de départ : démarre la localisation et rend la qualité du signal (`ready` à ≤ 20 m) ; arrêtée par `start` ou
    /// `cancelPreview()`. Avec la localisation refusée, le flux se termine aussitôt.
    ///
    /// Un départ ou un rattachement pendant les attentes garde la localisation pour sa course : l'aperçu se termine sans la toucher.
    public func gpsPreview() async -> AsyncStream<RunGPSQuality> {
        let (stream, continuation) = AsyncStream.makeStream(of: RunGPSQuality.self)
        guard run == nil, await authorizeLocation() == .authorized else {
            continuation.finish()
            return stream
        }
        await stopPreview()
        guard run == nil, !isTransitioning else {
            continuation.finish()
            return stream
        }
        continuation.yield(.searching)
        previewContinuation = continuation
        let generation = previewGeneration
        let points = await location.start()
        // Arrêté pendant l'attente (départ, annulation, autre aperçu) : celui qui l'a arrêté a aussi arrêté la localisation.
        // Une course rattachée entre-temps a relancé la sienne, qui ne doit pas être arrêtée.
        guard generation == previewGeneration, run == nil else {
            if generation == previewGeneration { previewContinuation = nil }
            continuation.finish()
            return stream
        }
        previewTask = Task {
            var last = RunGPSQuality.searching
            for await point in points {
                let quality = RunGPSQuality(accuracy: point.horizontalAccuracy)
                guard quality != last else { continue }
                continuation.yield(quality)
                last = quality
            }
            continuation.finish()
        }
        return stream
    }

    public func cancelPreview() async {
        await stopPreview()
    }

    // MARK: Départ

    public func start(_ launch: RunLaunch) async throws -> RunSnapshot {
        guard run == nil, !isTransitioning else { throw RunSessionError.alreadyRunning }
        isTransitioning = true
        defer { isTransitioning = false }
        guard try await drafts.load() == nil else { throw RunSessionError.alreadyRunning }
        let locationDenied = await authorizeLocation() != .authorized
        let canWriteHealth = await authorizeHealthWrite() == .authorized
        await stopPreview()

        let sessionID = UUID()
        let startedAt = now()
        // Un refus de Santé ou un échec de la séance HealthKit laisse courir sans elle : la course reste enregistrée dans Pulse.
        var heartRates: AsyncStream<Double>?
        if canWriteHealth { heartRates = try? await recorder.start(sessionID: sessionID, at: startedAt) }
        var points: AsyncStream<RunTrackPoint>?
        if !locationDenied { points = await location.start() }
        let draft = RunDraft(sessionID: sessionID, launch: launch, startedAt: startedAt, locationDenied: locationDenied,
                             updatedAt: startedAt)
        let active = ActiveRun(draft: draft, recordsHealth: heartRates != nil, at: startedAt)
        run = active
        consume(points: points, heartRates: heartRates)

        await activity.start(activityState(of: active, at: startedAt))
        try? await drafts.save(draft)
        if !locationDenied {
            await reminders.scheduleForgotten(at: startedAt.addingTimeInterval(Self.forgottenAfter))
        }
        publish()
        return current() ?? snapshot(of: active, at: startedAt)
    }

    // MARK: Pause

    public func pause() async {
        guard var active = run, !active.isPaused else { return }
        let date = now()
        active.draft.pauses.append(RunPause(start: date))
        active.builder.breakSegment()
        active.generation += 1
        active.markDraftWritten(at: date)
        active.lastActivityUpdate = date
        run = active
        if active.recordsHealth { await recorder.pause(at: date) }
        await apply(RunEffects(generation: active.generation, savesDraft: true, updatesActivity: true, reminder: .cancel),
                    for: active.sessionID)
        publish()
    }

    public func resume() async {
        guard var active = run, active.isPaused, let last = active.draft.pauses.indices.last else { return }
        let date = now()
        active.draft.pauses[last].end = date
        active.builder.breakSegment()
        active.generation += 1
        // Le déplacement repart de la reprise : l'oubli ne se déclenche jamais juste après.
        active.lastResumeAt = date
        active.reminderReference = date
        active.markDraftWritten(at: date)
        active.lastActivityUpdate = date
        run = active
        if active.recordsHealth { await recorder.resume(at: date) }
        let reminder: ReminderChange? = active.draft.locationDenied ? nil : .schedule(date.addingTimeInterval(Self.forgottenAfter))
        await apply(RunEffects(generation: active.generation, savesDraft: true, updatesActivity: true, reminder: reminder),
                    for: active.sessionID)
        publish()
    }

    // MARK: Oubli

    /// Le dernier déplacement si la course n'a pas bougé depuis 30 min, hors pause ; `nil` sans localisation.
    public func forgottenEnd() async -> Date? {
        guard let active = run, !active.isPaused, !active.draft.locationDenied else { return nil }
        let reference = active.movementReference
        return now().timeIntervalSince(reference) >= Self.forgottenAfter ? reference : nil
    }
}

extension RunSessionService {
    // MARK: États

    func publish() {
        guard let snapshot = current() else { return }
        snapshotContinuation?.yield(snapshot)
    }

    func endSnapshots() {
        snapshotContinuation?.finish()
        snapshotContinuation = nil
    }

    // MARK: Autorisations

    func authorizeLocation() async -> RunLocationAuthorization {
        let state = await location.authorization()
        return state == .notDetermined ? await location.requestAuthorization() : state
    }

    private func authorizeHealthWrite() async -> HealthWriteAccess {
        let access = await recorder.writeAccess()
        return access == .notDetermined ? await recorder.requestWriteAccess() : access
    }

    func stopPreview() async {
        guard previewTask != nil || previewContinuation != nil else { return }
        previewGeneration += 1
        previewTask?.cancel()
        previewTask = nil
        previewContinuation?.finish()
        previewContinuation = nil
        await location.stop()
    }

    // MARK: Tests

    /// Attend que `points` points, `heartRates` FC et `ticks` tops aient été traités depuis la création du service.
    func waitUntilHandled(points: Int = 0, heartRates: Int = 0, ticks: Int = 0) async {
        let waiter = HandledWaiter(points: points, heartRates: heartRates, ticks: ticks)
        guard !isReached(waiter) else { return }
        await withCheckedContinuation { continuation in
            waiters.append((waiter, continuation))
        }
    }

    private func isReached(_ waiter: HandledWaiter) -> Bool {
        handledPointCount >= waiter.points && handledHeartRateCount >= waiter.heartRates && handledTickCount >= waiter.ticks
    }

    func resumeWaiters() {
        let isReady = { (entry: (waiter: HandledWaiter, continuation: CheckedContinuation<Void, Never>)) in
            self.isReached(entry.waiter)
        }
        let ready = waiters.filter(isReady)
        waiters.removeAll(where: isReady)
        ready.forEach { $0.continuation.resume() }
    }
}

private struct HandledWaiter {
    var points: Int
    var heartRates: Int
    var ticks: Int
}
