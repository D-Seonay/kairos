import SwiftData

/// Quatrième version (M8a) : trois modèles locaux pour les valeurs d'Apple Health (`StoredRecoveryReading`,
/// `StoredImportedWorkout`, `StoredImportedBodyMeasurement`) ; aucun modèle synchronisé ne change (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    /// Les 15 modèles synchronisés, figés en V2a : `StoredRunTrack`, ajouté en V5, n'en fait pas partie ; `StoredProfile`,
    /// qui gagne les réglages de sommeil en V8, par sa copie figée.
    static let syncedModels: [any PersistentModel.Type] = [
        PulseSchemaV7.StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self, StoredUserExercise.self,
        StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self, StoredDailyRecovery.self, StoredCheckIn.self,
        StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self, StoredPersonalRecord.self,
        StoredExerciseSettings.self
    ]

    /// Les 6 modèles locaux, figés en V2a : `StoredRunDraft` et `StoredRunHealthSummary`, ajoutés en V5, n'en font pas partie.
    static let localModels: [any PersistentModel.Type] = [
        StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self,
        PulseSchemaV6.StoredRecoveryReading.self, StoredImportedWorkout.self, StoredImportedBodyMeasurement.self
    ]

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }
}
