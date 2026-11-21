import SwiftData

/// Quatrième version (M8a) : trois modèles locaux pour les valeurs d'Apple Health (`StoredRecoveryReading`,
/// `StoredImportedWorkout`, `StoredImportedBodyMeasurement`) ; aucun modèle synchronisé ne change (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
