import Foundation
import PulseDomain
import SwiftData

/// Deuxième version : `StoredProfile.firstName` et `StoredDailyRecovery.originalSessionChosen`, optionnels (migration légère).
/// Avant de modifier un modèle partagé, figer sa copie dans la version précédente et ajouter une version :
/// le test d'empreinte échoue sinon.
public enum PulseSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    /// Les modèles actuels, sauf ceux qui ont changé depuis la V2, remplacés par leur copie figée.
    public static var models: [any PersistentModel.Type] {
        [PulsePersistence.StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self,
         StoredUserExercise.self, StoredWorkoutSession.self, StoredWorkoutSet.self, PulsePersistence.StoredScheduledDay.self,
         PulsePersistence.StoredDailyRecovery.self, PulsePersistence.StoredCheckIn.self, PulsePersistence.StoredSupplement.self,
         PulsePersistence.StoredSupplementIntake.self, PulsePersistence.StoredBodyMeasurement.self,
         PulsePersistence.StoredPersonalRecord.self] + PersistenceStack.localModels
    }
}

extension PulseSchemaV2 {
    /// Copie figée de `StoredProgram` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredProgram {
        public var id: UUID = UUID()
        public var name: String = ""
        public var templateID: String?
        public var sessionsPerWeek: Int = 0
        public var weekLayout: Data?
        public var isArchived: Bool = false
        @Relationship(deleteRule: .cascade, inverse: \StoredRoutineDay.program) public var days: [StoredRoutineDay]? = []
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredRoutineDay` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredRoutineDay {
        public var id: UUID = UUID()
        public var order: Int = 0
        public var name: String = ""
        public var kind: String = RoutineDayKind.strength.rawValue
        public var runType: String?
        public var runTargetMinutes: Int?
        public var runTargetKm: Double?
        public var program: StoredProgram?
        @Relationship(deleteRule: .cascade, inverse: \StoredRoutineExercise.day) public var exercises: [StoredRoutineExercise]? = []
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredRoutineExercise` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredRoutineExercise {
        public var id: UUID = UUID()
        public var order: Int = 0
        public var contentExerciseID: String?
        public var userExerciseID: UUID?
        public var sets: Int = 3
        public var repsMin: Int = 8
        public var repsMax: Int = 12
        public var targetRPE: Double = 8
        public var restSeconds: Int = 90
        public var supersetGroup: Int?
        public var day: StoredRoutineDay?
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredUserExercise` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredUserExercise {
        public var id: UUID = UUID()
        public var name: String = ""
        public var primaryMuscle: String = Muscle.chest.rawValue
        public var secondaryMuscles: Data?
        public var equipment: String = Equipment.machine.rawValue
        public var pattern: String = MovementPattern.horizontalPush.rawValue
        public var region: String = BodyRegion.upper.rawValue
        public var isUnilateral: Bool = false
        public var defaultIncrementKg: Double = 2.5
        public var defaultRestSeconds: Int = 90
        public var isArchived: Bool = false
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredWorkoutSession` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredWorkoutSession {
        public var id: UUID = UUID()
        public var startedAt: Date = Date()
        public var endedAt: Date?
        public var kind: String = SessionKind.strength.rawValue
        public var source: String = SessionSource.pulse.rawValue
        public var status: String = SessionStatus.inProgress.rawValue
        public var programID: UUID?
        public var routineDayID: UUID?
        public var title: String = ""
        public var appliedAdjustments: Data?
        public var refusedAdjustments: Data?
        public var overallRPE: Double?
        public var note: String?
        public var tonnageKg: Double = 0
        public var durationMinutes: Double?
        public var distanceMeters: Double?
        public var averageHeartRate: Double?
        public var estimatedRPE: Double?
        public var healthKitUUID: String?
        @Relationship(deleteRule: .cascade, inverse: \StoredWorkoutSet.session) public var sets: [StoredWorkoutSet]? = []
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()
        public var deletedAt: Date?

        public init() {}
    }

    /// Copie figée de `StoredWorkoutSet` en V2 (d8ad52a) : ne pas modifier.
    @Model
    public final class StoredWorkoutSet {
        public var id: UUID = UUID()
        public var order: Int = 0
        public var contentExerciseID: String?
        public var userExerciseID: UUID?
        public var exerciseName: String = ""
        public var setType: String = SetType.working.rawValue
        public var supersetGroup: Int?
        public var plannedWeightKg: Double?
        public var plannedReps: Int?
        public var actualWeightKg: Double?
        public var actualReps: Int?
        public var rpe: Double?
        public var restSeconds: Int?
        public var completedAt: Date?
        public var isPersonalRecord: Bool = false
        public var replacedContentExerciseID: String?
        public var replacedUserExerciseID: UUID?
        public var replacementReason: String?
        public var session: StoredWorkoutSession?
        public var deletedAt: Date?

        public init() {}
    }
}
