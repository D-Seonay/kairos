#if DEBUG
import Foundation
import PulseContent
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import SwiftUI
import TrainFeature

/// Les doublures des aperçus : une vraie séance en mémoire (développé couché, dips et pec deck en super set, gainage) sur un
/// historique de développé couché, pour que les valeurs proposées, « Dernière fois » et le repos soient ceux de l'app.
@MainActor
enum LivePreviewSupport {
    enum Scenario {
        /// Rien de validé.
        case fresh
        /// Deux séries validées : le repos court.
        case resting
        /// Le clavier sur la charge de la deuxième série.
        case keypad
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    private static let bench = ExerciseReference.content(id: "bench-press-barbell")

    static let launch = SessionLaunch(
        title: "Pectoraux et triceps",
        day: RoutineDay(order: 0, name: "Pectoraux et triceps", kind: .strength, exercises: [
            RoutineExercise(order: 0, exercise: bench, sets: 3, repsMin: 8, repsMax: 12, targetRPE: 7.5, restSeconds: 165),
            RoutineExercise(order: 1, exercise: .content(id: "dips"), sets: 2, repsMin: 8, repsMax: 12, targetRPE: 8,
                            restSeconds: 90, supersetGroup: 1),
            RoutineExercise(order: 2, exercise: .content(id: "pec-deck-machine"), sets: 2, repsMin: 10, repsMax: 15,
                            targetRPE: 8, restSeconds: 60, supersetGroup: 1),
            RoutineExercise(order: 3, exercise: .content(id: "plank"), sets: 2, repsMin: 30, repsMax: 45, targetRPE: 8,
                            restSeconds: 60)
        ]),
        policy: ProgressionPolicy(allowsIncrease: true))

    /// Le modèle d'une séance démarrée. L'horloge est celle du mur : le repos de l'aperçu doit courir pour de bon.
    static func model(_ scenario: Scenario) async -> LiveSessionModel? {
        let environment = await environment()
        guard let session = try? await environment.service.start(launch) else { return nil }
        let model = LiveSessionModel(session: session, environment: environment)
        await apply(scenario, to: model)
        return model
    }

    /// Un service sur des dépôts en mémoire, avec l'historique de développé couché.
    static func environment() async -> LiveSessionEnvironment {
        let clock: @Sendable () -> Date = { Date() }
        let library = ContentLibrary.bundled
        let workouts = InMemoryWorkoutRepository()
        let profiles = InMemoryProfileRepository()
        let userExercises = InMemoryUserExerciseRepository()
        let personalRecords = InMemoryPersonalRecordRepository()
        let settings = InMemoryExerciseSettingsRepository()
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises,
                                     library: library, now: clock)
        let service = ActiveSessionService(
            store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
            userExercises: userExercises, records: records, library: library, restNotifier: StubRestTimerNotifier(),
            activity: StubSessionActivityController(), calendar: calendar, now: clock)
        let importer = HevyImporter(workouts: workouts, userExercises: userExercises, records: records,
                                    mappings: InMemoryHevyMappingStore(), library: library, calendar: calendar, now: clock)
        let train = TrainEnvironment(
            profiles: profiles, programs: InMemoryProgramRepository(), recovery: InMemoryRecoveryRepository(calendar: calendar),
            workouts: workouts, userExercises: userExercises, exerciseSettings: settings, personalRecords: personalRecords,
            records: records, importer: importer, library: library, calendar: calendar, now: clock)
        await seedBenchHistory(into: workouts)
        return LiveSessionEnvironment(service: service, train: train, notifications: StubNotificationAuthorizer(granted: true),
                                      calendar: calendar, now: clock)
    }

    private static func apply(_ scenario: Scenario, to model: LiveSessionModel) async {
        switch scenario {
        case .fresh:
            break
        case .resting:
            for set in model.session.exercises[0].sets.prefix(2) { await model.tap(set: set.id) }
        case .keypad:
            await model.tap(set: model.session.exercises[0].sets[0].id)
            let exercise = model.session.exercises[0]
            model.focus(KeypadField(exercise: exercise.id, set: exercise.sets[1].id, kind: .weight))
        }
    }

    /// Le développé couché de la semaine dernière : 60 × 12, 70 × 5, 70 × 5.
    private static func seedBenchHistory(into workouts: InMemoryWorkoutRepository) async {
        let day = Date(timeIntervalSinceNow: -7 * 86_400)
        let sets = [(60.0, 12), (70.0, 5), (70.0, 5)].enumerated().map { index, entry in
            WorkoutSet(order: index, exercise: bench, exerciseName: "Développé couché", setType: .working,
                       actualWeightKg: entry.0, actualReps: entry.1)
        }
        try? await workouts.save(WorkoutSession(startedAt: day, kind: .strength, source: .pulse, status: .completed,
                                                title: "Push", sets: sets, createdAt: day, updatedAt: day))
    }
}

/// Prépare la séance de l'aperçu puis affiche l'écran dessus.
private struct LivePreviewHost: View {
    let scenario: LivePreviewSupport.Scenario
    @State private var model: LiveSessionModel?

    var body: some View {
        Group {
            if let model {
                LiveSessionView(model: model, onFinish: {}, onAbandon: {})
            } else {
                ProgressView()
            }
        }
        .task { model = await LivePreviewSupport.model(scenario) }
        .preferredColorScheme(.dark)
    }
}

#Preview("Séance neuve") {
    LivePreviewHost(scenario: .fresh)
}

#Preview("Repos en cours") {
    LivePreviewHost(scenario: .resting)
}

#Preview("Clavier sur la charge") {
    LivePreviewHost(scenario: .keypad)
}

#Preview("Accessibilité XL") {
    LivePreviewHost(scenario: .keypad)
        .dynamicTypeSize(.accessibility3)
}
#endif
