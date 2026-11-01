// swiftlint:disable force_unwrapping
import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Synchronization
import Testing
@testable import TodayFeature

/// Calendrier grégorien Europe/Paris en français et dates locales de Paris.
enum TodayClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)!
    }
}

/// Une horloge que le test peut avancer.
final class MutableClock: Sendable {
    private let value: Mutex<Date>

    init(_ text: String) {
        value = Mutex(TodayClock.date(text))
    }

    var now: Date { value.withLock { $0 } }

    func set(_ text: String) {
        value.withLock { $0 = TodayClock.date(text) }
    }
}

/// Une source Apple Santé qu'on peut faire échouer après coup, au-dessus d'un scénario.
actor SwitchableHealthSource: HealthSampleSource {
    private let inner: any HealthSampleSource
    private var fails = false

    init(_ inner: any HealthSampleSource) {
        self.inner = inner
    }

    func setFails(_ value: Bool) {
        fails = value
    }

    private func check() throws {
        if fails { throw FailingHealthSource.Failure.unavailable }
    }

    func requestAuthorization() async throws { try check() }

    func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try check()
        return try await inner.sdnnSamples(from: from, to: to)
    }

    func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try check()
        return try await inner.restingHeartRateSamples(from: from, to: to)
    }

    func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        try check()
        return try await inner.sleepIntervals(from: from, to: to)
    }

    func profileHints() async throws -> HealthProfileHints {
        try check()
        return try await inner.profileHints()
    }
}

/// Les doublures d'un écran d'accueil, et le modèle construit dessus.
@MainActor
struct TodayFixture {
    let profiles = InMemoryProfileRepository()
    let programs = InMemoryProgramRepository()
    let source: SwitchableHealthSource
    let clock: MutableClock
    let environment: TodayEnvironment

    init(scenario: HealthScenario = .goodNight, at start: String = "2026-11-02T08:00") {
        let calendar = TodayClock.calendar
        let clock = MutableClock(start)
        self.clock = clock
        source = SwitchableHealthSource(ScenarioHealthSource(scenario: scenario, now: clock.now, calendar: calendar))
        environment = TodayEnvironment(
            profiles: profiles, programs: programs,
            nightHistory: NightHistory(source: source, cache: InMemoryHealthSampleCache(), calendar: calendar),
            scores: DailyScoreService(recovery: InMemoryRecoveryRepository(calendar: calendar), calendar: calendar),
            library: .bundled, calendar: calendar, now: { clock.now })
    }

    func makeModel() -> TodayModel {
        TodayModel(environment: environment)
    }

    /// Un profil terminé, avec le programme `templateID` adopté.
    @discardableResult
    func adopt(_ templateID: String, firstName: String? = nil) async throws -> Program {
        let library = ContentLibrary.bundled
        let template = try #require(library.programTemplate(id: templateID))
        let program = ProgramAdopter(library: library).adopt(
            template, equipment: .fullGym, painAreas: [], restWeekdays: [], now: clock.now)
        try await programs.save(program)
        try await profiles.save(UserProfile(
            firstName: firstName, onboardingCompletedAt: clock.now, activeProgramID: program.id,
            createdAt: clock.now, updatedAt: clock.now))
        return program
    }
}
// swiftlint:enable force_unwrapping
