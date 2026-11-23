import Foundation
import PulseDomain
import Testing

@testable import PulseServices

/// Un brouillon qui délègue à `InMemoryRunDraftStore` et compte les écritures.
actor CountingRunDraftStore: RunDraftStore {
    private let inner: InMemoryRunDraftStore
    private(set) var saveCount = 0

    init(_ draft: RunDraft? = nil) {
        inner = InMemoryRunDraftStore(draft)
    }

    func load() async throws -> RunDraft? {
        try await inner.load()
    }

    func save(_ draft: RunDraft) async throws {
        saveCount += 1
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
    let workouts = InMemoryWorkoutRepository()
    let tracks = InMemoryRunTrackRepository()
    let profiles = InMemoryProfileRepository()
    let preferences = InMemoryRunPreferencesStore()
    let service: RunSessionService

    init(recorder: StubRunWorkoutRecorder = StubRunWorkoutRecorder(),
         location: StubRunLocationTracker = StubRunLocationTracker(), draft: RunDraft? = nil) {
        self.recorder = recorder
        self.location = location
        drafts = CountingRunDraftStore(draft)
        let clock = clock
        service = RunSessionService(
            recorder: recorder, location: location, announcer: announcer, activity: activity, reminders: reminders,
            drafts: drafts, workouts: workouts, tracks: tracks, profiles: profiles, preferences: preferences,
            spokenText: Self.spokenText, now: { clock.now }, calendar: TestClock.calendar)
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
