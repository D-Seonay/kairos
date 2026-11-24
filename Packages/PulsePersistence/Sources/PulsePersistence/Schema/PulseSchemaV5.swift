import SwiftData

/// Cinquième version (V2a, course GPS) : le tracé synchronisé `StoredRunTrack`, et deux modèles locaux, le brouillon
/// `StoredRunDraft` et le résumé cardio `StoredRunHealthSummary` ; aucun modèle existant ne change (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    /// Les 16 modèles synchronisés, figés en V2b : `StoredSessionPhoto`, ajouté en V6, n'en fait pas partie.
    static let syncedModels: [any PersistentModel.Type] = [
        StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self, StoredUserExercise.self,
        StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self, StoredDailyRecovery.self, StoredCheckIn.self,
        StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self, StoredPersonalRecord.self,
        StoredExerciseSettings.self, StoredRunTrack.self
    ]

    /// Les 8 modèles locaux, figés en V2b : aucun modèle local n'est ajouté en V6.
    static let localModels: [any PersistentModel.Type] = [
        StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self,
        PulseSchemaV6.StoredRecoveryReading.self, StoredImportedWorkout.self, StoredImportedBodyMeasurement.self,
        StoredRunDraft.self, StoredRunHealthSummary.self
    ]

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }
}
