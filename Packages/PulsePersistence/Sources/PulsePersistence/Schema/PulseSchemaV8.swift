import Foundation
import PulseDomain
import SwiftData

/// Huitième version (objectif de sommeil) : `StoredProfile`, synchronisé, gagne l'objectif de sommeil, les heures de lever
/// en semaine et le week-end et le rappel de coucher, optionnels ou avec valeur par défaut (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV8: VersionedSchema {
    public static let versionIdentifier = Schema.Version(8, 0, 0)

    /// Les 17 modèles synchronisés, figés en V9 : `StoredDailyRecovery` et `StoredCheckIn`, qui gagnent leur clé de jour civil
    /// en V9, par leur copie figée.
    static let syncedModels: [any PersistentModel.Type] = [
        PulsePersistence.StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self,
        StoredUserExercise.self, StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self,
        PulseSchemaV8.StoredDailyRecovery.self, PulseSchemaV8.StoredCheckIn.self, StoredSupplement.self, StoredSupplementIntake.self,
        StoredBodyMeasurement.self, StoredPersonalRecord.self, StoredExerciseSettings.self, StoredRunTrack.self,
        StoredSessionPhoto.self
    ]

    /// Les 8 modèles locaux, figés en V9 : `StoredRecoveryReading` (clé de jour civil) et `StoredRunDraft` (points en paquets)
    /// par leur copie figée ; `StoredRunDraftChunk`, ajouté en V9, n'en fait pas partie.
    static let localModels: [any PersistentModel.Type] = [
        StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self,
        PulseSchemaV8.StoredRecoveryReading.self, StoredImportedWorkout.self, StoredImportedBodyMeasurement.self,
        PulseSchemaV8.StoredRunDraft.self, StoredRunHealthSummary.self
    ]

    public static var models: [any PersistentModel.Type] {
        syncedModels + localModels
    }
}

extension PulseSchemaV8 {
    /// Copie figée de `StoredDailyRecovery` en V8 (inchangée depuis la V2) : ne pas modifier.
    @Model
    public final class StoredDailyRecovery {
        public var id: UUID = UUID()
        public var day: Date = Date()
        public var score: Double = 0
        public var category: String = RecoveryCategory.normal.rawValue
        public var isEstimated: Bool = false
        public var hrvScore: Double?
        public var restingHeartRateScore: Double?
        public var sleepScore: Double?
        public var sdnnMs: Double?
        public var sdnnBaselineMs: Double?
        public var restingHeartRate: Double?
        public var restingHeartRateBaseline: Double?
        public var asleepMinutes: Int?
        public var deepMinutes: Int?
        public var missingFactors: Data?
        public var calibration: Data?
        public var adjustments: Data?
        public var frozenAt: Date?
        public var originalSessionChosen: Bool?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredCheckIn` en V8 (inchangée depuis la V1) : ne pas modifier.
    @Model
    public final class StoredCheckIn {
        public var id: UUID = UUID()
        public var day: Date = Date()
        public var sleepAnswer: Int = 0
        public var painAnswer: Int = 0
        public var motivationAnswer: Int = 0
        public var score: Double = 0
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredRecoveryReading` en V8 (inchangée depuis la V7) : ne pas modifier.
    @Model
    public final class StoredRecoveryReading {
        @Attribute(.unique) public var day: Date = Date()
        public var sdnnMs: Double?
        public var sdnnBaselineMs: Double?
        public var restingHeartRate: Double?
        public var restingHeartRateBaseline: Double?
        public var asleepMinutes: Int?
        public var deepMinutes: Int?
        public var coreMinutes: Int?
        public var remMinutes: Int?
        public var unspecifiedMinutes: Int?
        public var awakeMinutes: Int?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()

        public init() {}
    }

    /// Copie figée de `StoredRunDraft` en V8 (inchangée depuis la V5) : ne pas modifier.
    @Model
    public final class StoredRunDraft {
        @Attribute(.unique) public var id: UUID = UUID()
        public var payload: Data?
        public var updatedAt: Date = Date()

        public init() {}
    }
}
