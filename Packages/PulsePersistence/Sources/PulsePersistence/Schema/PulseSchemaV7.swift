import SwiftData

/// Septième version (phases de sommeil) : `StoredRecoveryReading`, local, gagne les minutes de léger, de paradoxal, d'endormi
/// sans phase et d'éveil, optionnelles (migration légère). Aucun modèle synchronisé ne change : les phases ne vont pas sur iCloud.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
