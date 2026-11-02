import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Synchronization
import Testing

/// Une horloge que le test peut avancer.
final class MutableClock: Sendable {
    private let value: Mutex<Date>

    init(_ text: String) {
        value = Mutex(TestClock.date(text))
    }

    var now: Date { value.withLock { $0 } }

    func set(_ text: String) {
        value.withLock { $0 = TestClock.date(text) }
    }
}

/// Une source Apple Santé qu'on peut faire échouer après coup, et qui compte les lectures de changements demandées.
actor SwitchableHealthSource: HealthSampleSource {
    private let inner: any HealthSampleSource
    private var fails = false
    private(set) var changeCalls = 0

    init(_ inner: any HealthSampleSource) {
        self.inner = inner
    }

    func setFails(_ value: Bool) {
        fails = value
    }

    private func check() throws {
        if fails { throw UnavailableHealthSource.Failure.unavailable }
    }

    func requestAuthorization() async throws { try check() }

    func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        changeCalls += 1
        try check()
        return try await inner.changes(of: signal, since: anchor, from: start)
    }

    func profileHints() async throws -> HealthProfileHints {
        try check()
        return try await inner.profileHints()
    }
}

/// Un planificateur qui suspend chaque planification derrière une porte avant de la confier à la doublure.
struct HoldingNotificationScheduler: NotificationScheduling {
    let inner: StubNotificationScheduler
    let gate: Gate

    func scheduleMorningScore(_ message: MorningScoreMessage) async {
        await gate.pass()
        await inner.scheduleMorningScore(message)
    }

    func cancelMorningScore() async {
        await inner.cancelMorningScore()
    }
}

/// Un publicateur qui suspend chaque publication derrière une porte avant de la confier à la doublure.
struct HoldingWidgetPublisher: WidgetPublishing {
    let inner: StubWidgetPublisher
    let gate: Gate

    func publish(_ snapshot: WidgetSnapshot) async {
        await gate.pass()
        await inner.publish(snapshot)
    }

    func clear() async {
        await inner.clear()
    }
}

/// Un rafraîchisseur du jour au-dessus de dépôts et de doublures en mémoire, que le test peut relire.
struct RefresherFixture {
    let profiles = InMemoryProfileRepository()
    let programs = InMemoryProgramRepository()
    let recovery: InMemoryRecoveryRepository
    let source: SwitchableHealthSource
    let widgets = StubWidgetPublisher()
    let notifications: StubNotificationScheduler
    let activity = InMemoryDayActivityLog()
    let clock: MutableClock
    let refresher: DayRefresher

    /// Sans `adopt`, il n'y a ni profil ni programme. Avec `gate`, chaque notification planifiée attend que la porte s'ouvre ;
    /// avec `publishGate`, chaque publication de l'instantané.
    init(scenario: HealthScenario, at start: String = "2026-11-02T08:00", holdingNotificationsAt gate: Gate? = nil,
         holdingPublishesAt publishGate: Gate? = nil) {
        let calendar = TestClock.calendar
        let clock = MutableClock(start)
        let recovery = InMemoryRecoveryRepository(calendar: calendar)
        let source = SwitchableHealthSource(ScenarioHealthSource(scenario: scenario, now: clock.now, calendar: calendar))
        let notifications = StubNotificationScheduler()
        let scheduler: any NotificationScheduling = gate.map { HoldingNotificationScheduler(inner: notifications, gate: $0) }
            ?? notifications
        var publisher: any WidgetPublishing = widgets
        if let publishGate {
            publisher = HoldingWidgetPublisher(inner: widgets, gate: publishGate)
        }
        self.clock = clock
        self.recovery = recovery
        self.source = source
        self.notifications = notifications
        refresher = DayRefresher(
            profiles: profiles, programs: programs, recovery: recovery,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: recovery, calendar: calendar),
            widgets: publisher, notifications: scheduler, activity: activity,
            calendar: calendar, now: { clock.now })
    }

    /// PPL 3 adopté (lundi Push, mardi repos), et un profil dont l'onboarding est terminé, sauf si `onboarded` est faux.
    func adopt(onboarded: Bool = true) async throws {
        let library = ContentLibrary.bundled
        let template = try #require(library.programTemplate(id: "ppl-3"))
        let program = ProgramAdopter(library: library).adopt(
            template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: clock.now)
        try await programs.save(program)
        try await profiles.save(UserProfile(
            onboardingCompletedAt: onboarded ? clock.now : nil, activeProgramID: program.id,
            createdAt: clock.now, updatedAt: clock.now))
    }

    func score(on text: String) async throws -> DailyRecovery? {
        let day = TestClock.date(text)
        let next = TestClock.calendar.date(byAdding: .day, value: 1, to: day) ?? day
        return try await recovery.dailyRecoveries(from: day, to: next).first
    }
}
