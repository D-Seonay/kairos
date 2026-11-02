import SwiftData

/// Troisième version (M4) : réglages par exercice, cibles par série, notes d'exercice, séries chronométrées,
/// type de charge des exercices perso, dates des enfants ; tout optionnel ou avec valeur par défaut (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
