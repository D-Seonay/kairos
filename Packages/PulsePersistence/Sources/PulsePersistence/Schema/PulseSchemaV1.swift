import Foundation
import PulseDomain
import SwiftData

/// Première version du schéma, figée. Tout changement ultérieur passe par une nouvelle version et une étape de migration.
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    /// Les modèles actuels, sauf ceux qui ont changé depuis la V1, remplacés par leur copie figée : les six modèles
    /// d'entraînement modifiés en V3 n'avaient pas changé entre V1 et V2, d'où leurs copies figées V2.
    public static var models: [any PersistentModel.Type] {
        [StoredProfile.self, PulseSchemaV2.StoredProgram.self, PulseSchemaV2.StoredRoutineDay.self,
         PulseSchemaV2.StoredRoutineExercise.self, PulseSchemaV2.StoredUserExercise.self,
         PulseSchemaV2.StoredWorkoutSession.self, PulseSchemaV2.StoredWorkoutSet.self, PulsePersistence.StoredScheduledDay.self,
         StoredDailyRecovery.self, PulsePersistence.StoredCheckIn.self, PulsePersistence.StoredSupplement.self,
         PulsePersistence.StoredSupplementIntake.self, PulsePersistence.StoredBodyMeasurement.self,
         PulsePersistence.StoredPersonalRecord.self] + PersistenceStack.localModels
    }
}

extension PulseSchemaV1 {
    /// Copie figée de `StoredProfile` en V1 (863127d) : ne pas modifier.
    @Model
    public final class StoredProfile {
        public var id: UUID = UUID()
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

    /// Copie figée de `StoredDailyRecovery` en V1 (863127d) : ne pas modifier.
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
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }
}
