import Foundation
import SwiftData

/// Où vivent les données : iCloud, fichier local seul, ou mémoire (tests).
public enum StoreMode: Sendable, Equatable {
    case cloud
    case localOnly
    case inMemory
}

/// Construit le conteneur SwiftData à deux configurations : `synced` (CloudKit privé) et `local` (jamais synchronisé).
public enum PersistenceStack {
    public static let cloudContainerIdentifier = "iCloud.fr.seonay.pulse"

    public static var syncedModels: [any PersistentModel.Type] {
        [StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self, StoredUserExercise.self,
         StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self, StoredDailyRecovery.self, StoredCheckIn.self,
         StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self, StoredPersonalRecord.self]
    }

    public static var localModels: [any PersistentModel.Type] {
        [StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self]
    }

    public static func makeContainer(mode: StoreMode) throws -> ModelContainer {
        switch mode {
        case .inMemory:
            return try makeContainer(configurations: [
                ModelConfiguration("synced", schema: Schema(syncedModels), isStoredInMemoryOnly: true, cloudKitDatabase: .none),
                ModelConfiguration("local", schema: Schema(localModels), isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ])
        case .localOnly:
            return try makeContainer(directory: try storeDirectory())
        case .cloud:
            let directory = try storeDirectory()
            return try makeContainer(configurations: [
                ModelConfiguration("synced", schema: Schema(syncedModels), url: directory.appending(path: "synced.store"),
                                   cloudKitDatabase: .private(cloudContainerIdentifier)),
                ModelConfiguration("local", schema: Schema(localModels), url: directory.appending(path: "local.store"),
                                   cloudKitDatabase: .none)
            ])
        }
    }

    /// Magasins `synced.store` et `local.store` dans `directory`, sans CloudKit, migrés jusqu'à la dernière version.
    public static func makeContainer(directory: URL) throws -> ModelContainer {
        try makeContainer(configurations: [
            ModelConfiguration("synced", schema: Schema(syncedModels), url: directory.appending(path: "synced.store"),
                               cloudKitDatabase: .none),
            ModelConfiguration("local", schema: Schema(localModels), url: directory.appending(path: "local.store"),
                               cloudKitDatabase: .none)
        ])
    }

    private static func makeContainer(configurations: [ModelConfiguration]) throws -> ModelContainer {
        try ModelContainer(for: Schema(versionedSchema: PulseSchemaV2.self), migrationPlan: PulseMigrationPlan.self,
                           configurations: configurations)
    }

    private static func storeDirectory() throws -> URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Pulse", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
