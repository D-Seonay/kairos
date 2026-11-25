import SwiftData

/// Huitième version (objectif de sommeil) : `StoredProfile`, synchronisé, gagne l'objectif de sommeil, les heures de lever
/// en semaine et le week-end et le rappel de coucher, optionnels ou avec valeur par défaut (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV8: VersionedSchema {
    public static let versionIdentifier = Schema.Version(8, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
