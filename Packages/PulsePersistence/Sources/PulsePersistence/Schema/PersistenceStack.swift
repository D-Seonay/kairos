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
         StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self]
    }

    public static var localModels: [any PersistentModel.Type] {
        []
    }

    public static func makeContainer(mode: StoreMode) throws -> ModelContainer {
        let synced = Schema(syncedModels)
        let local = Schema(localModels)
        let configurations: [ModelConfiguration]
        switch mode {
        case .inMemory:
            configurations = [
                ModelConfiguration("synced", schema: synced, isStoredInMemoryOnly: true, cloudKitDatabase: .none),
                ModelConfiguration("local", schema: local, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        case .localOnly:
            configurations = [
                ModelConfiguration("synced", schema: synced, url: try storeURL("synced"), cloudKitDatabase: .none),
                ModelConfiguration("local", schema: local, url: try storeURL("local"), cloudKitDatabase: .none)
            ]
        case .cloud:
            configurations = [
                ModelConfiguration("synced", schema: synced, url: try storeURL("synced"),
                                   cloudKitDatabase: .private(cloudContainerIdentifier)),
                ModelConfiguration("local", schema: local, url: try storeURL("local"), cloudKitDatabase: .none)
            ]
        }
        return try ModelContainer(for: Schema(versionedSchema: PulseSchemaV1.self), migrationPlan: PulseMigrationPlan.self,
                                  configurations: configurations)
    }

    private static func storeURL(_ name: String) throws -> URL {
        let directory = URL.applicationSupportDirectory.appending(path: "Pulse", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "\(name).store")
    }
}
