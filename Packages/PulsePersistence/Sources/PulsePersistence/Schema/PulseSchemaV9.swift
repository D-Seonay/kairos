import SwiftData

/// Neuvième version (jours civils, brouillon en paquets) : `StoredDailyRecovery` et `StoredCheckIn`, synchronisés, et
/// `StoredRecoveryReading`, local, gagnent `dayKey` (« 2026-11-27 »), optionnelle ; `StoredRunDraft`, local, gagne le format en
/// paquets et ses compteurs, avec valeur par défaut ; `StoredRunDraftChunk`, local, porte les points ajoutés (migration légère).
/// Les clés des lignes existantes sont remplies, et les doublons d'un même jour retirés, par `DayKeyRepair` à l'ouverture du magasin.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV9: VersionedSchema {
    public static let versionIdentifier = Schema.Version(9, 0, 0)

    public static var models: [any PersistentModel.Type] {
        PersistenceStack.syncedModels + PersistenceStack.localModels
    }
}
