import Foundation
import LiveSessionFeature
import OnboardingFeature
import PlanningFeature
import PulseServices
import SupplementsFeature
import TodayFeature
import TrainFeature

// MARK: - Environnements des fonctionnalités

extension AppDependencies {
    /// Les nuits lues dans la source Apple Santé, mises en cache dans le magasin.
    var nightHistory: NightHistory {
        NightHistory(source: healthSource, cache: healthCache, calendar: calendar)
    }

    func onboardingEnvironment() -> OnboardingEnvironment {
        OnboardingEnvironment(profiles: profiles, programs: programs, health: healthSource, nightHistory: nightHistory,
                              scores: scores, notifications: notifications, library: content, stepStore: onboardingSteps,
                              calendar: calendar, now: now)
    }

    func todayEnvironment() -> TodayEnvironment {
        TodayEnvironment(refresher: refresher, workouts: workouts, userExercises: userExercises, exerciseSettings: exerciseSettings,
                         activeSession: liveSession, library: content, calendar: calendar, now: now)
    }

    func trainEnvironment() -> TrainEnvironment {
        TrainEnvironment(profiles: profiles, programs: programs, recovery: recovery, workouts: workouts, userExercises: userExercises,
                         exerciseSettings: exerciseSettings, personalRecords: personalRecords, records: records,
                         importer: hevyImporter, library: content, activeSession: liveSession, scheduledDays: scheduledDays,
                         calendar: calendar, now: now)
    }

    func planningEnvironment() -> PlanningEnvironment {
        PlanningEnvironment(service: planning, train: trainEnvironment(), calendar: calendar, now: now)
    }

    /// L'écran en direct passe par le même service que l'accueil et l'onglet Séance ; il demande l'autorisation des notifications
    /// par l'autorisateur de l'app (une doublure accordée dans les modes des tests d'interface, refusée dans les tests).
    func liveSessionEnvironment() -> LiveSessionEnvironment {
        LiveSessionEnvironment(service: liveSession, train: trainEnvironment(), notifications: liveSessionNotifications,
                               supplements: supplementsEnvironment(), calendar: calendar, now: now)
    }

    /// Les compléments demandent l'autorisation des notifications comme l'écran en direct : par l'autorisateur de l'app (une
    /// doublure dans les modes des tests d'interface et dans les tests).
    func supplementsEnvironment() -> SupplementsEnvironment {
        SupplementsEnvironment(service: supplementService, notifications: liveSessionNotifications, calendar: calendar, now: now)
    }

    /// La saisie d'une séance passée (spec M4 §19.4) : un service à part, en mémoire, sans notification ni Live Activity, pour
    /// ne jamais toucher à la séance en direct. Un appel, un service : le coordinateur garde le sien.
    func pastSessionEnvironment() -> LiveSessionEnvironment {
        let service = ActiveSessionService.pastSessions(
            workouts: workouts, profiles: profiles, settings: exerciseSettings, userExercises: userExercises, records: records,
            library: content, calendar: calendar, now: now, health: liveSession.health)
        return LiveSessionEnvironment(service: service, train: trainEnvironment(), notifications: liveSessionNotifications,
                                      calendar: calendar, now: now)
    }
}
