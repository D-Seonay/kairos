import Foundation
import PulseDomain
import PulseServices
@testable import RunFeature
import Synchronization

/// Calendrier grégorien Europe/Paris en français, et dates locales de Paris.
enum RunTestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// `"2026-11-24T07:00"` lu en heure de Paris.
    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // swiftlint:disable:next force_unwrapping
        return formatter.date(from: text)!
    }
}

/// Une horloge que le test avance.
final class RunMutableClock: Sendable {
    private let value: Mutex<Date>

    init(_ date: Date) {
        value = Mutex(date)
    }

    var now: Date { value.withLock { $0 } }

    func advance(minutes: Double) {
        value.withLock { $0 = $0.addingTimeInterval(minutes * 60) }
    }
}

/// Un vrai `RunSessionService` sur les doublures du domaine et des dépôts en mémoire, et le coordinateur construit dessus.
@MainActor
struct RunFeatureFixture {
    nonisolated static let start = RunTestClock.date("2026-11-24T07:00")

    let clock = RunMutableClock(Self.start)
    let recorder: StubRunWorkoutRecorder
    let location: StubRunLocationTracker
    let drafts: InMemoryRunDraftStore
    let workouts = InMemoryWorkoutRepository()
    let tracks = InMemoryRunTrackRepository()
    let preferences = InMemoryRunPreferencesStore()
    let service: RunSessionService
    let strengthActive: Bool

    init(recorder: StubRunWorkoutRecorder = StubRunWorkoutRecorder(),
         location: StubRunLocationTracker = StubRunLocationTracker(), draft: RunDraft? = nil, strengthActive: Bool = false) {
        self.recorder = recorder
        self.location = location
        self.strengthActive = strengthActive
        drafts = InMemoryRunDraftStore(draft)
        let clock = clock
        service = RunSessionService(
            recorder: recorder, location: location, announcer: StubRunAnnouncer(), activity: StubRunActivityController(),
            reminders: StubRunReminderScheduler(), drafts: drafts, workouts: workouts, tracks: tracks,
            profiles: InMemoryProfileRepository(), preferences: preferences, spokenText: RunText.spokenText(for:),
            now: { clock.now }, calendar: RunTestClock.calendar,
            keepAliveTicks: { _ in AsyncStream { $0.finish() } })
    }

    var environment: RunEnvironment {
        let strengthActive = strengthActive
        let clock = clock
        return RunEnvironment(
            service: service, tracks: tracks, preferences: preferences, isStrengthSessionActive: { strengthActive },
            now: { clock.now }, calendar: RunTestClock.calendar)
    }

    func coordinator() -> RunCoordinator {
        RunCoordinator(environment: environment)
    }

    /// Un brouillon de course laissé par un processus précédent : quelques points au nord du départ.
    static func interruptedDraft() -> RunDraft {
        let points = (0..<60).map { second in
            RunTrackPoint(timestamp: start.addingTimeInterval(Double(second)), latitude: 48.8566 + Double(second) * 3 / 111_320,
                          longitude: 2.3522, horizontalAccuracy: 5)
        }
        return RunDraft(sessionID: UUID(), launch: .free(), startedAt: start, points: points,
                        updatedAt: points.last?.timestamp ?? start)
    }
}
