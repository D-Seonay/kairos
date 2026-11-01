import Foundation
import PulseContent
import PulseDomain
import PulseHealth
import PulsePersistence
import SwiftData

/// Les dépendances externes de l'app, assemblées une fois au lancement.
struct AppDependencies: Sendable {
    let health: any HealthReading
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
    let supplements: any SupplementRepository
    let bodyMeasurements: any BodyMeasurementRepository
    let personalRecords: any PersonalRecordRepository
    let healthCache: any HealthSampleCache
    let activeSession: any ActiveSessionStore
    let inspector: any StoreInspector
    let exporter: any DataExporter
    let eraser: any DataEraser
    let seeder: SampleDataSeeder

    /// Apple Santé réel quand l'appareil le permet ; iCloud sur appareil, fichier local sur simulateur, mémoire en dernier recours.
    static func live() -> AppDependencies {
        let health: any HealthReading = HealthKitReader.isAvailable ? HealthKitReader() : StubHealthReader()
        #if targetEnvironment(simulator)
        let preferred = StoreMode.localOnly
        #else
        let preferred = StoreMode.cloud
        #endif
        do {
            return try make(health: health, calendar: .current, mode: preferred, error: nil)
        } catch {
            let message = String(localized: "Le stockage n'a pas pu être ouvert ; les données ne seront pas conservées.")
            guard let fallback = try? make(health: health, calendar: .current, mode: .inMemory, error: message) else { crash(error) }
            return fallback
        }
    }

    static func preview() -> AppDependencies {
        testing()
    }

    /// Conteneur en mémoire et doublures, pour les tests et les aperçus.
    static func testing(health: any HealthReading = StubHealthReader(), calendar: Calendar = .current) -> AppDependencies {
        guard let dependencies = try? make(health: health, calendar: calendar, mode: .inMemory, error: nil) else { crash(nil) }
        return dependencies
    }

    private static func make(health: any HealthReading, calendar: Calendar, mode: StoreMode, error: String?) throws -> AppDependencies {
        let container = try PersistenceStack.makeContainer(mode: mode)
        let content = ContentLibrary.bundled
        let exporter = SwiftDataExporter(container: container, appVersion: appVersion, contentVersion: content.contentVersion,
                                         exerciseNames: { content.exercise(id: $0)?.name.fr })
        let eraser = SwiftDataEraser(container: container, defaultsSuite: nil,
                                     defaultsDomain: Bundle.main.bundleIdentifier ?? "fr.seonay.pulse",
                                     healthEraser: StubHealthEraser(), notifications: nil,
                                     exportsDirectory: SwiftDataExporter.exportsDirectory)
        return AppDependencies(
            health: health, calendar: calendar, content: content, container: container, storeMode: mode, storeError: error,
            profiles: SwiftDataProfileRepository(modelContainer: container),
            programs: SwiftDataProgramRepository(modelContainer: container),
            userExercises: SwiftDataUserExerciseRepository(modelContainer: container),
            workouts: SwiftDataWorkoutRepository(modelContainer: container),
            scheduledDays: SwiftDataScheduledDayRepository(modelContainer: container),
            recovery: SwiftDataRecoveryRepository(modelContainer: container, calendar: calendar),
            supplements: SwiftDataSupplementRepository(modelContainer: container),
            bodyMeasurements: SwiftDataBodyMeasurementRepository(modelContainer: container),
            personalRecords: SwiftDataPersonalRecordRepository(modelContainer: container),
            healthCache: SwiftDataHealthSampleCache(modelContainer: container),
            activeSession: SwiftDataActiveSessionStore(modelContainer: container),
            inspector: SwiftDataStoreInspector(container: container, cloudEnabled: mode == .cloud),
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
