import SwiftData

/// Sixième version (V2b, photos) : la photo de séance synchronisée `StoredSessionPhoto` ; aucun modèle existant ne change
/// (migration légère). Les photos de corps n'ont aucun modèle : elles vivent en fichiers protégés, hors de SwiftData.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
