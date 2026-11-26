import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Tout ce dont l'onboarding a besoin du dehors : dépôts, Apple Santé, notifications, contenu, étape retenue et horloge.
public struct OnboardingEnvironment: Sendable {
    public var profiles: any ProfileRepository
    public var programs: any ProgramRepository
    public var health: any HealthSampleSource
    public var nightHistory: NightHistory
    public var scores: DailyScoreService
    public var notifications: any NotificationAuthorizing
    public var library: ContentLibrary
    public var stepStore: any OnboardingStepStore
    public var calendar: Calendar
    public var now: @Sendable () -> Date
    /// Retient, dans les mêmes préférences que l'étape, que l'accès à Apple Santé a été demandé : l'app ne propose
    /// « Connecter Apple Santé » qu'à qui a passé cette étape. En mémoire par défaut (tests, aperçus).
    public var once: any OnceLog

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, health: any HealthSampleSource,
                nightHistory: NightHistory, scores: DailyScoreService, notifications: any NotificationAuthorizing,
                library: ContentLibrary, stepStore: any OnboardingStepStore, calendar: Calendar,
                now: @escaping @Sendable () -> Date, once: any OnceLog = InMemoryOnceLog()) {
        self.profiles = profiles
        self.programs = programs
        self.health = health
        self.nightHistory = nightHistory
        self.scores = scores
        self.notifications = notifications
        self.library = library
        self.stepStore = stepStore
        self.calendar = calendar
        self.now = now
        self.once = once
    }
}
