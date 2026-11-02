import Foundation
import OnboardingFeature
import PulseContent
import PulseDomain
import PulseHealth
import PulsePersistence
import PulseServices
import SwiftData
import TodayFeature
import WidgetFeature

/// Les dépendances externes de l'app, assemblées une fois au lancement.
struct AppDependencies: Sendable {
    /// Préférences du mode mémoire (`-PulseStore inMemory`), vidées à chaque lancement.
    static let memoryDefaultsSuite = "fr.seonay.pulse.memory"
    /// Préférences des tests de la cible app, jamais celles de l'app réelle.
    static let testingDefaultsSuite = "fr.seonay.pulse.tests"

    let health: any HealthReading
    let healthSource: any HealthSampleSource
    let notifications: any NotificationAuthorizing
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
    let healthCache: any HealthSampleCache
    /// Dernière ouverture et dernier jour annoncé, dans la suite de préférences que la suppression totale vide.
    let activity: any DayActivityLog
    /// Le seul passage qui lit Apple Santé et met le score du jour à jour, au premier plan comme en arrière-plan.
    let refresher: DayRefresher
    /// Les réveils d'Apple Santé ; `nil` sans Apple Santé, avec un scénario de lancement et en mode mémoire.
    let backgroundDelivery: HealthKitBackgroundDelivery?
    let activeSession: any ActiveSessionStore
    let inspector: any StoreInspector
    let exporter: any DataExporter
    let eraser: any DataEraser
    let seeder: SampleDataSeeder

    /// Ce qui change entre l'app réelle, le mode mémoire des tests d'interface et les tests de la cible app.
    private struct Wiring {
        var health: any HealthReading
        var healthSource: any HealthSampleSource
        var notifications: any NotificationAuthorizing
        var healthEraser: any HealthErasing
        /// Le groupe d'apps de l'app réelle ; une doublure en mode mémoire et dans les tests.
        var widgets: any WidgetPublishing
        /// La notification du matin ; une doublure en mode mémoire et dans les tests.
        var morningScore: any NotificationScheduling
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

        /// Le mode mémoire n'écrit ni dans les préférences, ni dans le groupe d'apps, ni dans les notifications de l'app réelle.
        mutating func useMemoryDoubles(defaultsSuite suite: String) {
            defaultsSuite = suite
            notifications = StubNotificationAuthorizer(granted: false)
            widgets = StubWidgetPublisher()
            morningScore = StubNotificationScheduler()
            notificationCanceling = nil
            backgroundDelivery = nil
        }
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
        let scheduler = UserNotificationScheduler()
        var wiring = Wiring(health: reader ?? StubHealthReader(), healthSource: healthSource,
                            notifications: UserNotificationAuthorizer(), healthEraser: StubHealthEraser(),
                            widgets: AppGroupWidgetPublisher(file: WidgetSnapshotFile.appGroup()),
                            morningScore: scheduler, notificationCanceling: scheduler,
                            backgroundDelivery: launch.healthScenario == nil ? reader.map(HealthKitBackgroundDelivery.init) : nil,
                            inspector: nil, defaultsSuite: nil, calendar: calendar, now: now, launch: launch)
        if launch.storeInMemory {
            UserDefaults(suiteName: memoryDefaultsSuite)?.removePersistentDomain(forName: memoryDefaultsSuite)
            wiring.useMemoryDoubles(defaultsSuite: memoryDefaultsSuite)
            guard let memory = try? make(wiring, mode: .inMemory, error: nil) else { crash(nil) }
            return memory
        }
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
            notifications: StubNotificationAuthorizer(granted: false), healthEraser: healthEraser,
            widgets: StubWidgetPublisher(), morningScore: StubNotificationScheduler(), notificationCanceling: nil,
            backgroundDelivery: nil, inspector: inspector, defaultsSuite: testingDefaultsSuite, calendar: calendar, now: now,
            launch: LaunchOptions())
        guard let dependencies = try? make(wiring, mode: .inMemory, error: nil) else { crash(nil) }
        return dependencies
    }

    private static func make(_ wiring: Wiring, mode: StoreMode, error: String?) throws -> AppDependencies {
        let container = try PersistenceStack.makeContainer(mode: mode)
        let content = ContentLibrary.bundled
        let calendar = wiring.calendar
        let exporter = SwiftDataExporter(container: container, appVersion: appVersion, contentVersion: content.contentVersion,
                                         exerciseNames: { content.exercise(id: $0)?.name.fr })
        let storeEraser = SwiftDataEraser(container: container, defaultsSuite: wiring.defaultsSuite,
                                          defaultsDomain: wiring.defaultsSuite ?? Bundle.main.bundleIdentifier ?? "fr.seonay.pulse",
                                          healthEraser: wiring.healthEraser, notifications: wiring.notificationCanceling,
                                          widgets: wiring.widgets, exportsDirectory: SwiftDataExporter.exportsDirectory)
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
        // La suppression totale attend la fin d'un rafraîchissement en cours, qui republierait l'instantané effacé.
        let eraser = SerializedDataEraser(refresher: refresher, inner: storeEraser)
        return AppDependencies(
            health: wiring.health, healthSource: wiring.healthSource, notifications: wiring.notifications,
            onboardingSteps: UserDefaultsOnboardingStepStore(suiteName: wiring.defaultsSuite),
            now: wiring.now, launch: wiring.launch,
            calendar: calendar, content: content, container: container, storeMode: mode, storeError: error,
            profiles: profiles, programs: programs,
            userExercises: SwiftDataUserExerciseRepository(modelContainer: container),
            workouts: SwiftDataWorkoutRepository(modelContainer: container),
            scheduledDays: SwiftDataScheduledDayRepository(modelContainer: container),
            recovery: recovery, scores: scores,
            supplements: SwiftDataSupplementRepository(modelContainer: container),
            bodyMeasurements: SwiftDataBodyMeasurementRepository(modelContainer: container),
            personalRecords: SwiftDataPersonalRecordRepository(modelContainer: container),
            healthCache: healthCache, activity: activity, refresher: refresher, backgroundDelivery: wiring.backgroundDelivery,
            activeSession: SwiftDataActiveSessionStore(modelContainer: container),
            inspector: wiring.inspector ?? SwiftDataStoreInspector(container: container, cloudEnabled: mode == .cloud),
            exporter: exporter, eraser: eraser, seeder: SampleDataSeeder(container: container, calendar: calendar))
    }

    private static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

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
        TodayEnvironment(refresher: refresher, workouts: workouts, library: content, calendar: calendar, now: now)
    }
}
