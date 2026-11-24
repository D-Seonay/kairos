import SwiftData

/// Plan de migration : chaque version du schéma, et une étape légère entre deux versions successives.
public enum PulseMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [PulseSchemaV1.self, PulseSchemaV2.self, PulseSchemaV3.self, PulseSchemaV4.self, PulseSchemaV5.self, PulseSchemaV6.self,
         PulseSchemaV7.self]
    }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: PulseSchemaV1.self, toVersion: PulseSchemaV2.self),
         .lightweight(fromVersion: PulseSchemaV2.self, toVersion: PulseSchemaV3.self),
         .lightweight(fromVersion: PulseSchemaV3.self, toVersion: PulseSchemaV4.self),
         .lightweight(fromVersion: PulseSchemaV4.self, toVersion: PulseSchemaV5.self),
         .lightweight(fromVersion: PulseSchemaV5.self, toVersion: PulseSchemaV6.self),
         .lightweight(fromVersion: PulseSchemaV6.self, toVersion: PulseSchemaV7.self)]
    }
}
