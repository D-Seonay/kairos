import Foundation
import LiveSessionFeature
import OnboardingFeature
import PulseContent
import PulseDomain
import PulseHealth
import PulsePersistence
import PulseServices
import SwiftData
import TodayFeature
import TrainFeature
import WidgetFeature

/// Les dépendances externes de l'app, assemblées une fois au lancement.
struct AppDependencies: Sendable {
    #if DEBUG
    /// Préférences du mode mémoire (`-PulseStore inMemory`), vidées à chaque lancement.
    static let memoryDefaultsSuite = "fr.seonay.pulse.memory"
    /// Préférences du mode disque (`-PulseStore disk`), conservées entre deux lancements et vidées avec `-PulseResetStore YES`.
    static let diskDefaultsSuite = "fr.seonay.pulse.disk"
    #endif
    /// Préférences des tests de la cible app, jamais celles de l'app réelle.
    static let testingDefaultsSuite = "fr.seonay.pulse.tests"

    let health: any HealthReading
    let healthSource: any HealthSampleSource
    let notifications: any NotificationAuthorizing
    /// L'autorisation que l'écran en direct demande ; celle des tests d'interface est accordée, pour que l'avis « notifications
    /// désactivées » ne couvre pas l'écran.
    let liveSessionNotifications: any NotificationAuthorizing
    let onboardingSteps: any OnboardingStepStore
    let now: @Sendable () -> Date
    let launch: LaunchOptions
    let calendar: Calendar
    let content: ContentLibrary
    let container: ModelContainer
    let storeMode: StoreMode
    let storeError: String?
    let profiles: any ProfileRepository
    let programs: any ProgramRepository
    let userExercises: any UserExerciseRepository
    let workouts: any WorkoutRepository
    let scheduledDays: any ScheduledDayRepository
    let recovery: any RecoveryRepository
    /// Le seul service du score du jour : l'onboarding et l'accueil le partagent, ses écritures passent par une même file.
    let scores: DailyScoreService
    let supplements: any SupplementRepository
    let bodyMeasurements: any BodyMeasurementRepository
    let personalRecords: any PersonalRecordRepository
    let exerciseSettings: any ExerciseSettingsRepository
    /// Le seul recalcul des records : l'import Hevy et les écrans de l'historique le partagent, ses recalculs passent par une même file.
    let records: RecordsService
    /// Les correspondances Hevy retenues, dans la suite de préférences que la suppression totale vide.
    let hevyMappings: UserDefaultsHevyMappingStore
    let hevyImporter: HevyImporter
    let healthCache: any HealthSampleCache
    /// Dernière ouverture et dernier jour annoncé, dans la suite de préférences que la suppression totale vide.
    let activity: any DayActivityLog
    /// Le seul passage qui lit Apple Santé et met le score du jour à jour, au premier plan comme en arrière-plan.
    let refresher: DayRefresher
    /// Les réveils d'Apple Santé ; `nil` sans Apple Santé, avec un scénario de lancement et en mode mémoire.
    let backgroundDelivery: HealthKitBackgroundDelivery?
    let activeSession: any ActiveSessionStore
    /// Le seul chemin vers la séance en cours : l'accueil, l'onglet Séance, l'écran en direct et les boutons de la Live Activity.
    let liveSession: ActiveSessionService
    /// La Live Activity de la séance ; la racine y ferme, au lancement, celles qui ne correspondent plus à la séance en cours.
    let sessionActivity: any SessionActivityControlling
    let inspector: any StoreInspector
    let exporter: any DataExporter
    let eraser: any DataEraser
    let seeder: SampleDataSeeder

    /// Ce qui change entre l'app réelle, le mode mémoire des tests d'interface et les tests de la cible app.
    private struct Wiring {
        var health: any HealthReading
        var healthSource: any HealthSampleSource
        var notifications: any NotificationAuthorizing
        var liveSessionNotifications: any NotificationAuthorizing
        var healthEraser: any HealthErasing
        /// Le groupe d'apps de l'app réelle ; une doublure en mode mémoire et dans les tests.
        var widgets: any WidgetPublishing
        /// La notification du matin ; une doublure en mode mémoire et dans les tests.
        var morningScore: any NotificationScheduling
        /// La notification de fin de repos ; une doublure en mode mémoire et dans les tests.
        var restNotifier: any RestTimerNotifying
        /// La Live Activity de la séance ; une doublure en mode mémoire et dans les tests.
        var sessionActivity: any SessionActivityControlling
        /// `nil` : la suppression totale n'a aucune notification à retirer.
        var notificationCanceling: (any NotificationCanceling)?
        var backgroundDelivery: HealthKitBackgroundDelivery?
        /// `nil` : l'inspecteur du magasin SwiftData.
        var inspector: (any StoreInspector)?
        /// `nil` : `UserDefaults.standard`.
        var defaultsSuite: String?
        var calendar: Calendar
        var now: @Sendable () -> Date
        var launch: LaunchOptions

        #if DEBUG
        /// Les modes des tests d'interface (mémoire, disque) n'écrivent ni dans les préférences, ni dans le groupe d'apps, ni dans
        /// les notifications de l'app réelle. L'écran en direct y a l'autorisation ; l'onboarding garde le refus.
        mutating func useMemoryDoubles(defaultsSuite suite: String) {
            defaultsSuite = suite
            notifications = StubNotificationAuthorizer(granted: false)
            liveSessionNotifications = StubNotificationAuthorizer(granted: true)
            widgets = StubWidgetPublisher()
            morningScore = StubNotificationScheduler()
            restNotifier = StubRestTimerNotifier()
            sessionActivity = StubSessionActivityController()
            notificationCanceling = nil
            backgroundDelivery = nil
        }
        #endif
    }

    /// Apple Santé réel quand l'appareil le permet ; iCloud sur appareil, fichier local sur simulateur, mémoire en dernier recours.
    /// En Debug, les options de lancement remplacent le magasin, Apple Santé et l'horloge.
    static func live() -> AppDependencies {
        #if DEBUG
        let launch = LaunchOptions.parse(ProcessInfo.processInfo.arguments)
        #else
        let launch = LaunchOptions()
        #endif
        let calendar = Calendar.current
        let now: @Sendable () -> Date
        if let fixed = launch.fixedNow {
            now = { fixed }
        } else {
            now = { Date.now }
        }
        let reader = HealthKitReader.isAvailable ? HealthKitReader() : nil
        let healthSource: any HealthSampleSource
        if let scenario = launch.healthScenario {
            healthSource = ScenarioHealthSource(scenario: scenario, now: now(), calendar: calendar)
        } else if let reader {
            healthSource = reader
        } else {
            healthSource = UnavailableHealthSource()
        }
        let scheduler = UserNotificationScheduler(now: now)
        let authorizer = UserNotificationAuthorizer()
        var wiring = Wiring(health: reader ?? StubHealthReader(), healthSource: healthSource,
                            notifications: authorizer, liveSessionNotifications: authorizer, healthEraser: StubHealthEraser(),
                            widgets: AppGroupWidgetPublisher(file: WidgetSnapshotFile.appGroup()),
                            morningScore: scheduler, restNotifier: scheduler, sessionActivity: SessionActivityController(),
                            notificationCanceling: scheduler,
                            backgroundDelivery: launch.healthScenario == nil ? reader.map(HealthKitBackgroundDelivery.init) : nil,
                            inspector: nil, defaultsSuite: nil, calendar: calendar, now: now, launch: launch)
        #if DEBUG
        if let tested = launchStore(&wiring) { return tested }
        #endif
        #if targetEnvironment(simulator)
        let preferred = StoreMode.localOnly
        #else
        let preferred = StoreMode.cloud
        #endif
        do {
            return try make(wiring, mode: preferred, error: nil)
        } catch {
            let message = String(localized: "Le stockage n'a pas pu être ouvert ; les données ne seront pas conservées.")
            guard let fallback = try? make(wiring, mode: .inMemory, error: message) else { crash(error) }
            return fallback
        }
    }

    static func preview() -> AppDependencies {
        testing()
    }

    /// Conteneur en mémoire, doublures et suite de préférences dédiée, pour les tests et les aperçus.
    static func testing(health: any HealthReading = StubHealthReader(), healthSource: (any HealthSampleSource)? = nil,
                        healthEraser: any HealthErasing = StubHealthEraser(), calendar: Calendar = .current,
                        inspector: (any StoreInspector)? = nil) -> AppDependencies {
        let now: @Sendable () -> Date = { Date.now }
        let wiring = Wiring(
            health: health,
            healthSource: healthSource ?? ScenarioHealthSource(scenario: .noData, now: now(), calendar: calendar),
            notifications: StubNotificationAuthorizer(granted: false),
            liveSessionNotifications: StubNotificationAuthorizer(granted: false), healthEraser: healthEraser,
            widgets: StubWidgetPublisher(), morningScore: StubNotificationScheduler(), restNotifier: StubRestTimerNotifier(),
            sessionActivity: StubSessionActivityController(), notificationCanceling: nil,
            backgroundDelivery: nil, inspector: inspector, defaultsSuite: testingDefaultsSuite, calendar: calendar, now: now,
            launch: LaunchOptions())
        guard let dependencies = try? make(wiring, mode: .inMemory, error: nil) else { crash(nil) }
        return dependencies
    }

    private static func make(_ wiring: Wiring, mode: StoreMode, error: String?) throws -> AppDependencies {
        try make(wiring, container: PersistenceStack.makeContainer(mode: mode), mode: mode, error: error)
    }

    private static func make(_ wiring: Wiring, container: ModelContainer, mode: StoreMode,
                             error: String?) throws -> AppDependencies {
        let content = ContentLibrary.bundled
        let calendar = wiring.calendar
        let recovery = SwiftDataRecoveryRepository(modelContainer: container, calendar: calendar)
        let profiles = SwiftDataProfileRepository(modelContainer: container)
        let programs = SwiftDataProgramRepository(modelContainer: container)
        let scores = DailyScoreService(recovery: recovery, calendar: calendar)
        let healthCache = SwiftDataHealthSampleCache(modelContainer: container)
        let activity = UserDefaultsDayActivityLog(suiteName: wiring.defaultsSuite)
        let refresher = DayRefresher(
            profiles: profiles, programs: programs, recovery: recovery,
            nightHistory: NightHistory(source: wiring.healthSource, cache: healthCache, calendar: calendar), scores: scores,
            widgets: wiring.widgets, notifications: wiring.morningScore, activity: activity,
            calendar: calendar, now: wiring.now)
        let userExercises = SwiftDataUserExerciseRepository(modelContainer: container)
        let workouts = SwiftDataWorkoutRepository(modelContainer: container)
        let personalRecords = SwiftDataPersonalRecordRepository(modelContainer: container)
        let records = RecordsService(workouts: workouts, records: personalRecords, userExercises: userExercises,
                                     library: content, now: wiring.now)
        let hevyMappings = UserDefaultsHevyMappingStore(suiteName: wiring.defaultsSuite)
        let activeSession = SwiftDataActiveSessionStore(modelContainer: container)
        let exerciseSettings = SwiftDataExerciseSettingsRepository(modelContainer: container)
        let liveSession = ActiveSessionService(
            store: activeSession, workouts: workouts, profiles: profiles, settings: exerciseSettings, userExercises: userExercises,
            records: records, library: content, restNotifier: wiring.restNotifier, activity: wiring.sessionActivity,
            calendar: calendar, now: wiring.now)
        return AppDependencies(
            health: wiring.health, healthSource: wiring.healthSource, notifications: wiring.notifications,
            liveSessionNotifications: wiring.liveSessionNotifications,
            onboardingSteps: UserDefaultsOnboardingStepStore(suiteName: wiring.defaultsSuite),
            now: wiring.now, launch: wiring.launch,
            calendar: calendar, content: content, container: container, storeMode: mode, storeError: error,
            profiles: profiles, programs: programs,
            userExercises: userExercises, workouts: workouts,
            scheduledDays: SwiftDataScheduledDayRepository(modelContainer: container),
            recovery: recovery, scores: scores,
            supplements: SwiftDataSupplementRepository(modelContainer: container),
            bodyMeasurements: SwiftDataBodyMeasurementRepository(modelContainer: container),
            personalRecords: personalRecords,
            exerciseSettings: exerciseSettings,
            records: records, hevyMappings: hevyMappings,
            hevyImporter: HevyImporter(workouts: workouts, userExercises: userExercises, records: records, mappings: hevyMappings,
                                       library: content, calendar: calendar, now: wiring.now),
            healthCache: healthCache, activity: activity, refresher: refresher, backgroundDelivery: wiring.backgroundDelivery,
            activeSession: activeSession, liveSession: liveSession, sessionActivity: wiring.sessionActivity,
            inspector: wiring.inspector ?? SwiftDataStoreInspector(container: container, cloudEnabled: mode == .cloud),
            exporter: SwiftDataExporter(container: container, appVersion: appVersion, contentVersion: content.contentVersion,
                                        exerciseNames: { content.exercise(id: $0)?.name.fr }),
            eraser: makeEraser(wiring, container: container, refresher: refresher),
            seeder: SampleDataSeeder(container: container, calendar: calendar))
    }

    /// Efface le magasin, les préférences, les notifications, l'instantané du widget et les exports. Elle attend la fin d'un
    /// rafraîchissement en cours, qui republierait l'instantané effacé.
    private static func makeEraser(_ wiring: Wiring, container: ModelContainer, refresher: DayRefresher) -> any DataEraser {
        let store = SwiftDataEraser(container: container, defaultsSuite: wiring.defaultsSuite,
                                    defaultsDomain: wiring.defaultsSuite ?? Bundle.main.bundleIdentifier ?? "fr.seonay.pulse",
                                    healthEraser: wiring.healthEraser, notifications: wiring.notificationCanceling,
                                    widgets: wiring.widgets, exportsDirectory: SwiftDataExporter.exportsDirectory)
        return SerializedDataEraser(refresher: refresher, inner: store)
    }

    private static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

    #if DEBUG
    /// Le mode mémoire ou le mode disque des tests d'interface, avec les doublures ; `nil` pour l'app réelle. Le mode disque
    /// garde ses données et ses préférences d'un lancement à l'autre, sauf avec `-PulseResetStore YES`.
    private static func launchStore(_ wiring: inout Wiring) -> AppDependencies? {
        let launch = wiring.launch
        if launch.storeInMemory {
            UserDefaults(suiteName: memoryDefaultsSuite)?.removePersistentDomain(forName: memoryDefaultsSuite)
            wiring.useMemoryDoubles(defaultsSuite: memoryDefaultsSuite)
            guard let memory = try? make(wiring, mode: .inMemory, error: nil) else { crash(nil) }
            return memory
        }
        guard launch.storeOnDisk else { return nil }
        let directory = FileManager.default.temporaryDirectory.appending(path: "PulseUITestStore", directoryHint: .isDirectory)
        if launch.resetsStore {
            UserDefaults(suiteName: diskDefaultsSuite)?.removePersistentDomain(forName: diskDefaultsSuite)
            try? FileManager.default.removeItem(at: directory)
        }
        wiring.useMemoryDoubles(defaultsSuite: diskDefaultsSuite)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return try make(wiring, container: PersistenceStack.makeContainer(directory: directory), mode: .localOnly, error: nil)
        } catch {
            crash(error)
        }
    }
    #endif

    private static func crash(_ error: (any Error)?) -> Never {
        fatalError("Impossible de créer le conteneur SwiftData : \(error.map { String(describing: $0) } ?? "inconnu")")
    }
}

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
                         importer: hevyImporter, library: content, activeSession: liveSession, calendar: calendar, now: now)
    }

    /// L'écran en direct passe par le même service que l'accueil et l'onglet Séance ; il demande l'autorisation des notifications
    /// par l'autorisateur de l'app (une doublure accordée dans les modes des tests d'interface, refusée dans les tests).
    func liveSessionEnvironment() -> LiveSessionEnvironment {
        LiveSessionEnvironment(service: liveSession, train: trainEnvironment(), notifications: liveSessionNotifications,
                               calendar: calendar, now: now)
    }
}
