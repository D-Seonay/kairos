import SwiftData

/// Plan de migration, vide en V1 : il existe pour que la première migration soit une étape et non une refonte.
public enum PulseMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [PulseSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
