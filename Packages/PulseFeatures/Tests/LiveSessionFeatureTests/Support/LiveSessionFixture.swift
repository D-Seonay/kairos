// swiftlint:disable force_unwrapping
import Foundation
@testable import LiveSessionFeature
import PulseContent
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Synchronization
import TrainFeature

/// Calendrier grégorien Europe/Paris en français, et dates locales de Paris.
enum LiveClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// `"2026-11-02T08:00"` lu en heure de Paris.
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
        value = Mutex(LiveClock.date(text))
    }

    var now: Date { value.withLock { $0 } }

    func set(_ text: String) {
        value.withLock { $0 = LiveClock.date(text) }
    }
}

/// Compte les retours haptiques demandés par le modèle.
@MainActor
final class HapticLog {
    var light = 0
    var validation = 0
    var restEnded = 0

    var haptics: LiveSessionHaptics {
        LiveSessionHaptics(light: { [self] in light += 1 }, validation: { [self] in validation += 1 },
                           restEnded: { [self] in restEnded += 1 })
    }
}

/// Un vrai `ActiveSessionService` sur des dépôts en mémoire, et l'environnement de la séance en direct construit dessus.
@MainActor
struct LiveFixture {
    static let bench = ExerciseReference.content(id: "bench-press-barbell")
    static let pecDeck = ExerciseReference.content(id: "pec-deck-machine")
    static let plank = ExerciseReference.content(id: "plank")

    let clock = MutableClock("2026-11-02T08:00")
    let workouts = InMemoryWorkoutRepository()
    let notifier = StubRestTimerNotifier()
    let activity = StubSessionActivityController()
    let authorizer: StubNotificationAuthorizer
    let service: ActiveSessionService
    let environment: LiveSessionEnvironment
    let haptics = HapticLog()

    init(notificationsGranted: Bool = true, store: any ActiveSessionStore = InMemoryActiveSessionStore()) {
        let clock = clock
        let now: @Sendable () -> Date = { clock.now }
        let library = ContentLibrary.bundled
        let calendar = LiveClock.calendar
        let profiles = InMemoryProfileRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises,
                                     library: library, now: now)
        service = ActiveSessionService(store: store, workouts: workouts, profiles: profiles,
                                       settings: InMemoryExerciseSettingsRepository(), userExercises: userExercises,
                                       records: records, library: library, restNotifier: notifier, activity: activity,
                                       calendar: calendar, now: now)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: now)
        let train = TrainEnvironment(
            profiles: profiles, programs: InMemoryProgramRepository(), recovery: InMemoryRecoveryRepository(calendar: calendar),
            workouts: workouts, userExercises: userExercises, exerciseSettings: InMemoryExerciseSettingsRepository(),
            personalRecords: personalRecords, records: records, importer: importer, library: library, calendar: calendar, now: now)
        authorizer = StubNotificationAuthorizer(granted: notificationsGranted)
        environment = LiveSessionEnvironment(service: service, train: train, notifications: authorizer, calendar: calendar,
                                             now: now)
    }

    /// Bench (3 séries de 8 à 12, repos 120 s) puis pec deck (2 séries, repos 60 s).
    static let pushLaunch = SessionLaunch(
        title: "Push",
        day: RoutineDay(order: 0, name: "Push", kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: bench, sets: 3, repsMin: 8, repsMax: 12, targetRPE: 8, restSeconds: 120),
            RoutineExercise(order: 1, exercise: pecDeck, sets: 2, repsMin: 10, repsMax: 15, targetRPE: 8, restSeconds: 60)
        ]),
        policy: ProgressionPolicy(allowsIncrease: true))

    /// Une séance de pompes-gainage : un gainage, mesuré en secondes.
    static let plankLaunch = SessionLaunch(
        title: "Gainage",
        day: RoutineDay(order: 0, name: "Gainage", kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: plank, sets: 2, repsMin: 30, repsMax: 45, targetRPE: 8, restSeconds: 60)
        ]),
        policy: ProgressionPolicy(allowsIncrease: true))

    /// Le bench de la semaine dernière : 60 × 12, 70 × 5, 70 × 5.
    func seedBenchHistory() async throws {
        let day = LiveClock.date("2026-10-26T08:00")
        let sets = [(60.0, 12), (70.0, 5), (70.0, 5)].enumerated().map { index, entry in
            WorkoutSet(order: index, exercise: Self.bench, exerciseName: "Bench", setType: .working, actualWeightKg: entry.0,
                       actualReps: entry.1)
        }
        try await workouts.save(WorkoutSession(startedAt: day, kind: .strength, source: .pulse, status: .completed, title: "Push",
                                               sets: sets, createdAt: day, updatedAt: day))
    }

    /// Un modèle sur une séance déjà démarrée avec `launch`.
    func startedModel(_ launch: SessionLaunch = pushLaunch) async throws -> LiveSessionModel {
        let session = try await service.start(launch)
        return LiveSessionModel(session: session, environment: environment, haptics: haptics.haptics)
    }

    func coordinator() -> LiveSessionCoordinator {
        LiveSessionCoordinator(environment: environment)
    }
}
// swiftlint:enable force_unwrapping
