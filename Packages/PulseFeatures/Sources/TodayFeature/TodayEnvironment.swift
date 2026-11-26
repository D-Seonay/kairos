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
    /// Les nuits du cache, pour l'écran Nuit ouvert depuis la tuile Sommeil.
    public var nights: NightDetailService
    /// La demande d'accès à Apple Santé, pour « Connecter Apple Santé » sur la bannière du check-in ; `nil` : la bannière ne
    /// l'offre pas.
    public var healthAccess: HealthAccess?

    public init(refresher: DayRefresher, workouts: any WorkoutRepository, userExercises: any UserExerciseRepository,
                exerciseSettings: any ExerciseSettingsRepository, activeSession: ActiveSessionService, library: ContentLibrary,
                calendar: Calendar, now: @escaping @Sendable () -> Date, nights: NightDetailService,
                healthAccess: HealthAccess? = nil) {
        self.refresher = refresher
        self.workouts = workouts
        self.userExercises = userExercises
        self.exerciseSettings = exerciseSettings
        self.activeSession = activeSession
        self.library = library
        self.calendar = calendar
        self.now = now
        self.nights = nights
        self.healthAccess = healthAccess
    }
}
