import Foundation
import SwiftData

/// Sixième version (V2b, photos) : la photo de séance synchronisée `StoredSessionPhoto` ; aucun modèle existant ne change
/// (migration légère). Les photos de corps n'ont aucun modèle : elles vivent en fichiers protégés, hors de SwiftData.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

    /// Les 8 modèles locaux, figés en V7 : `StoredRecoveryReading`, qui gagne les minutes de phase en V7, par sa copie figée.
    static let localModels: [any PersistentModel.Type] = [
        StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self,
        StoredRecoveryReading.self, StoredImportedWorkout.self, StoredImportedBodyMeasurement.self,
        PulseSchemaV8.StoredRunDraft.self, StoredRunHealthSummary.self
    ]

    public static var models: [any PersistentModel.Type] {
        PulseSchemaV7.syncedModels + localModels
    }
}

extension PulseSchemaV6 {
    /// Copie figée de `StoredRecoveryReading` en V6 : ne pas modifier.
    @Model
    public final class StoredRecoveryReading {
        @Attribute(.unique) public var day: Date = Date()
        public var sdnnMs: Double?
        public var sdnnBaselineMs: Double?
        public var restingHeartRate: Double?
        public var restingHeartRateBaseline: Double?
        public var asleepMinutes: Int?
        public var deepMinutes: Int?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()

        public init() {}
    }
}
