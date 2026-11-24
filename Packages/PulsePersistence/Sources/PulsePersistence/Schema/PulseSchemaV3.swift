import SwiftData

/// Troisième version (M4) : réglages par exercice, cibles par série, notes d'exercice, séries chronométrées,
/// type de charge des exercices perso, dates des enfants ; tout optionnel ou avec valeur par défaut (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    /// Les modèles synchronisés figés de la V4 (inchangés depuis la V3) et la liste locale figée en M8a : les trois modèles locaux
    /// ajoutés en V4 n'en font pas partie.
    public static var models: [any PersistentModel.Type] {
        PulseSchemaV4.syncedModels + [StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self]
    }
}
