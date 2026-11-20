import Foundation
import PulseContent
import PulseDomain

/// La saisie d'une séance passée (spec M4 §19.4) passe par le même service que la séance en direct, sur une instance à part :
/// elle peut avoir lieu pendant une séance en cours sans toucher à son snapshot, à sa notification ni à sa Live Activity.
extension ActiveSessionService {
    // swiftlint:disable function_parameter_count
    /// Un service dont la séance tient en mémoire, sans notification de repos ni Live Activity. Une saisie interrompue par un
    /// arrêt de l'app est perdue **(choix du constructeur)** ; seule la séance enregistrée au récap compte.
    public static func pastSessions(workouts: any WorkoutRepository, profiles: any ProfileRepository,
                                    settings: any ExerciseSettingsRepository, userExercises: any UserExerciseRepository,
                                    records: RecordsService, library: ContentLibrary, calendar: Calendar,
                                    now: @escaping @Sendable () -> Date,
                                    health: HealthWorkoutExporter? = nil) -> ActiveSessionService {
        ActiveSessionService(store: InMemoryActiveSessionStore(), workouts: workouts, profiles: profiles, settings: settings,
                             userExercises: userExercises, records: records, library: library, restNotifier: SilentRestNotifier(),
                             activity: SilentSessionActivity(), calendar: calendar, now: now, health: health)
    }
    // swiftlint:enable function_parameter_count
}

private struct SilentRestNotifier: RestTimerNotifying {
    func scheduleRestEnd(at date: Date, message: RestEndMessage) async {}
    func cancelRestEnd() async {}
}

private struct SilentSessionActivity: SessionActivityControlling {
    func start(_ state: SessionActivityState) async {}
    func update(_ state: SessionActivityState) async {}
    func end() async {}
    func endAll(except sessionID: UUID?) async {}
}
