import SwiftData

/// Deuxième version : `StoredProfile.firstName` et `StoredDailyRecovery.originalSessionChosen`, optionnels (migration légère).
public enum PulseSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
