import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Tout ce dont l'accueil a besoin du dehors : le rafraîchisseur du jour (profil, programme, nuits, score), les séances enregistrées,
/// les exercices et les réglages de l'utilisateur, la séance en cours, le contenu et l'horloge.
public struct TodayEnvironment: Sendable {
    public var refresher: DayRefresher
    public var workouts: any WorkoutRepository
    public var userExercises: any UserExerciseRepository
    public var exerciseSettings: any ExerciseSettingsRepository
    public var activeSession: ActiveSessionService
    public var library: ContentLibrary
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(refresher: DayRefresher, workouts: any WorkoutRepository, userExercises: any UserExerciseRepository,
                exerciseSettings: any ExerciseSettingsRepository, activeSession: ActiveSessionService, library: ContentLibrary,
                calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.refresher = refresher
        self.workouts = workouts
        self.userExercises = userExercises
        self.exerciseSettings = exerciseSettings
        self.activeSession = activeSession
        self.library = library
        self.calendar = calendar
        self.now = now
    }
}
