import Foundation
import LiveSessionFeature
import OnboardingFeature
import PlanningFeature
import ProfileFeature
import PulseDomain
import PulseServices
import RunFeature
import StatsFeature
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
                              calendar: calendar, now: now, once: once, train: trainEnvironment())
    }

    /// « Connecter Apple Santé » (Paramètres, bannière du check-in) : la demande d'accès de l'onboarding, retenue dans les mêmes
    /// préférences. Comme à la fin de l'onboarding, les observateurs lancés au démarrage, avant l'accès, sont relancés.
    var healthAccess: HealthAccess {
        let delivery = backgroundDelivery
        return HealthAccess(source: healthSource, cache: healthCache, once: once, afterRequest: { delivery?.restart() })
    }

    /// Les autres entraînements d'Apple Santé (natation, HIIT, sport…), lus dans le cache : la charge de l'accueil et des Stats,
    /// et la grille d'assiduité. Ceux que Pulse a écrits ne comptent pas.
    var healthActivities: HealthActivities {
        HealthActivities(healthCache, profiles, calendar)
    }

    func todayEnvironment() -> TodayEnvironment {
        TodayEnvironment(refresher: refresher, workouts: workouts, userExercises: userExercises, exerciseSettings: exerciseSettings,
                         activeSession: liveSession, library: content, calendar: calendar, now: now,
                         nights: NightDetailService(cache: healthCache, profiles: profiles, calendar: calendar, now: now),
                         healthAccess: healthAccess, activities: healthActivities, checkInReminders: checkInReminders)
    }

    func trainEnvironment() -> TrainEnvironment {
        TrainEnvironment(profiles: profiles, programs: programs, recovery: recovery, workouts: workouts, userExercises: userExercises,
                         exerciseSettings: exerciseSettings, personalRecords: personalRecords, records: records,
                         importer: hevyImporter, library: content, activeSession: liveSession, scheduledDays: scheduledDays,
                         calendar: calendar, now: now, sessionPhotos: photos.sessions)
    }

    func planningEnvironment() -> PlanningEnvironment {
        PlanningEnvironment(service: planning, train: trainEnvironment(), calendar: calendar, now: now, tracks: run.tracks)
    }

    /// Le service des statistiques ne garde rien (il relit les dépôts à chaque lecture) : on le construit ici, avec les dépôts de l'app.
    func statsEnvironment() -> StatsEnvironment {
        let service = StatsService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recovery,
                                   records: personalRecords, userExercises: userExercises, library: content, calendar: calendar,
                                   now: now, runEfforts: run.bestEfforts, activities: healthActivities)
        return StatsEnvironment(service: service, train: trainEnvironment(), calendar: calendar, now: now,
                                nights: NightDetailService(cache: healthCache, profiles: profiles, calendar: calendar, now: now))
    }

    /// L'onglet Profil : le résumé et les pesées relisent les dépôts à chaque lecture, les réglages passent par le service partagé,
    /// et « Relire maintenant » lance le passage du jour comme un retour au premier plan. Les photos de corps arrivent avec leur
    /// authentification : sans elle, la ligne n'est pas proposée.
    func profileEnvironment() -> ProfileEnvironment {
        let profile = ProfileService(profiles: profiles, programs: programs, workouts: workouts, recoveries: recovery,
                                     records: personalRecords, userExercises: userExercises, library: content, calendar: calendar,
                                     now: now, runEfforts: run.bestEfforts)
        let refresher = refresher
        let notifications = notifications
        let bedtime = bedtimeReminderService
        return ProfileEnvironment(
            profile: profile, body: BodyService(measurements: bodyMeasurements, profiles: profiles, calendar: calendar, now: now),
            settings: settings, healthCache: healthCache, inspector: inspector, exporter: exporter, eraser: eraser,
            notificationStatus: notificationStatus,
            requestNotificationAuthorization: { await notifications.requestAuthorization() },
            refreshHealth: { _ = await refresher.refresh(origin: .foreground) },
            appVersion: Self.appVersion, privacyPolicyURL: Self.privacyPolicyURL, calendar: calendar, now: now,
            runPreferences: run.preferences, bodyPhotos: photos.body, ownerAuthentication: photos.ownerAuthentication,
            bodyPhotoLock: photos.bodyLock, bodyPhotoReminders: photos.reminders, train: trainEnvironment(),
            sleepPlan: { await bedtime.plan() }, healthAccess: healthAccess, checkInReminders: checkInReminders,
            cloudSync: cloudSync)
    }

    /// La politique de confidentialité, lue dans l'Info.plist (`PulsePrivacyPolicyURL`) ; `nil` tant que la clé est vide ou
    /// n'est pas une adresse web (M8 la remplit).
    static var privacyPolicyURL: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "PulsePrivacyPolicyURL") as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host() != nil else { return nil }
        return url
    }

    /// L'écran en direct passe par le même service que l'accueil et l'onglet Séance ; il demande l'autorisation des notifications
    /// par l'autorisateur de l'app (une doublure accordée dans les modes des tests d'interface, refusée dans les tests).
    func liveSessionEnvironment() -> LiveSessionEnvironment {
        LiveSessionEnvironment(service: liveSession, train: trainEnvironment(), notifications: liveSessionNotifications,
                               supplements: supplementsEnvironment(), calendar: calendar, now: now, reviewPrompt: reviewPrompt,
                               once: once)
    }

    /// La demande de note au récap (au plus une par version, gardée dans `UserDefaults`) ; aucune dans les modes des tests
    /// d'interface (`-PulseStore`), où la fenêtre système gênerait.
    var reviewPrompt: ReviewPrompt? {
        guard !launch.storeInMemory, !launch.storeOnDisk else { return nil }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return ReviewPrompt(store: UserDefaultsReviewRequestStore(suiteName: nil), appVersion: version)
    }

    /// La course passe par le seul service de course de l'app. Elle ne démarre pas pendant une séance de musculation, que la
    /// racine lit dans la séance des onglets.
    func runEnvironment(isStrengthSessionActive: @escaping @MainActor () -> Bool) -> RunEnvironment {
        RunEnvironment(service: run.service, tracks: run.tracks, preferences: run.preferences,
                       isStrengthSessionActive: isStrengthSessionActive, now: now, calendar: calendar,
                       sessionPhotos: photos.sessions)
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

extension HealthActivities {
    /// Les autres entraînements d'Apple Santé lus par l'app : ceux qu'elle a elle-même écrits (son identifiant) ne comptent pas.
    init(_ cache: any HealthSampleCache, _ profiles: any ProfileRepository, _ calendar: Calendar) {
        self.init(cache: cache, profiles: profiles, calendar: calendar, ownBundleIdentifier: Bundle.main.bundleIdentifier)
    }
}
