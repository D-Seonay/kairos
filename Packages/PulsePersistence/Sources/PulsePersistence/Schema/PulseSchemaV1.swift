import SwiftData

/// Première version du schéma. Tout changement ultérieur passe par une nouvelle version et une étape de migration.
public enum PulseSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
