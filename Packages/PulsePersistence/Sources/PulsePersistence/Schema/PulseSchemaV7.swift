import Foundation
import PulseDomain
import SwiftData

/// Septième version (phases de sommeil) : `StoredRecoveryReading`, local, gagne les minutes de léger, de paradoxal, d'endormi
/// sans phase et d'éveil, optionnelles (migration légère). Aucun modèle synchronisé ne change : les phases ne vont pas sur iCloud.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)

    /// Les 17 modèles synchronisés, figés en V8 : `StoredProfile`, qui gagne les réglages de sommeil en V8, par sa copie figée ;
    /// `StoredDailyRecovery` et `StoredCheckIn`, qui gagnent leur clé de jour en V9, par leur copie figée en V8.
    static let syncedModels: [any PersistentModel.Type] = [
        PulseSchemaV7.StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self,
        StoredUserExercise.self, StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self,
        PulseSchemaV8.StoredDailyRecovery.self, PulseSchemaV8.StoredCheckIn.self, StoredSupplement.self, StoredSupplementIntake.self,
        StoredBodyMeasurement.self, StoredPersonalRecord.self, StoredExerciseSettings.self, StoredRunTrack.self, StoredSessionPhoto.self
    ]

    public static var models: [any PersistentModel.Type] {
        syncedModels + PulseSchemaV8.localModels
    }
}

extension PulseSchemaV7 {
    /// Copie figée de `StoredProfile` en V7 : ne pas modifier.
    @Model
    public final class StoredProfile {
        public var id: UUID = UUID()
        public var firstName: String?
        public var sex: String = Sex.unspecified.rawValue
        public var birthDate: Date?
        public var heightCm: Double?
        public var weightKg: Double?
        public var strengthLevel: String = TrainingLevel.beginner.rawValue
        public var runningLevel: String = TrainingLevel.beginner.rawValue
        public var focus: Double = 0.5
        public var trainingDaysPerWeek: Int = 3
        public var restWeekdays: Data?
        public var equipmentAccess: String = EquipmentAccess.fullGym.rawValue
        public var painAreas: Data?
        public var weightUnit: String = WeightUnit.kg.rawValue
        public var adaptationEnabled: Bool = true
        public var antiInterferenceRulesDisabled: Data?
        public var upperIncrementKg: Double = 2.5
        public var lowerIncrementKg: Double = 5
        public var barWeightKg: Double = 20
        public var availablePlatesKg: Data?
        public var defaultRestSeconds: Int = 90
        public var autoWarmupEnabled: Bool = true
        public var theme: String = Theme.amber.rawValue
        public var morningScoreNotification: Bool = true
        public var morningScoreDeadlineMinutes: Int?
        public var supplementRemindersEnabled: Bool = true
        public var restTimerNotificationEnabled: Bool = true
        public var onboardingCompletedAt: Date?
        public var activeProgramID: UUID?
        public var deloadWeekStartedAt: Date?
        public var deloadDeclinedAt: Date?
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }
}
