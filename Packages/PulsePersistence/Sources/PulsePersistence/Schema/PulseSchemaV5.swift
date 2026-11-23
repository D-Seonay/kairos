import SwiftData

/// Cinquième version (V2a, course GPS) : le tracé synchronisé `StoredRunTrack`, et deux modèles locaux, le brouillon
/// `StoredRunDraft` et le résumé cardio `StoredRunHealthSummary` ; aucun modèle existant ne change (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
