import Foundation
import PulseDomain
import SwiftData

/// Toutes les données exportables, lues en une fois.
public struct ExportSnapshot: Sendable {
    public var profile: UserProfile?
    public var programs: [Program] = []
    public var userExercises: [UserExercise] = []
    public var exerciseSettings: [ExerciseSettings] = []
    public var workoutSessions: [WorkoutSession] = []
    public var runTracks: [RunTrack] = []
    public var sessionPhotos: [SessionPhoto] = []
    public var scheduledDays: [ScheduledDay] = []
    public var dailyRecoveries: [DailyRecovery] = []
    public var checkIns: [CheckIn] = []
    public var supplements: [Supplement] = []
    public var supplementIntakes: [SupplementIntake] = []
    public var bodyMeasurements: [BodyMeasurement] = []
    public var personalRecords: [PersonalRecord] = []

    public init() {}

    /// Identifiants de contenu référencés par les routines, les séries et les records.
    public var referencedContentExerciseIDs: Set<String> {
        var ids = Set<String>()
        for program in programs { ids.formUnion(program.days.flatMap(\.exercises).compactMap(\.exercise.contentID)) }
        for session in workoutSessions { ids.formUnion(session.sets.compactMap(\.exercise.contentID)) }
        ids.formUnion(exerciseSettings.compactMap(\.exercise.contentID))
        ids.formUnion(personalRecords.compactMap(\.exercise.contentID))
        return ids
    }
}

/// Lit les enregistrements non supprimés, triés comme les dépôts.
@ModelActor
public actor ExportSnapshotLoader {
    public func snapshot() throws -> ExportSnapshot {
        var snapshot = ExportSnapshot()
        snapshot.profile = try fetch(StoredProfile.self, #Predicate { $0.deletedAt == nil }, [SortDescriptor(\.createdAt)])
            .first?.toDomain()
        snapshot.programs = try fetch(StoredProgram.self, #Predicate { $0.deletedAt == nil },
                                      [SortDescriptor(\.createdAt), SortDescriptor(\.name)]).map { $0.toDomain() }
        snapshot.userExercises = try fetch(StoredUserExercise.self, #Predicate { $0.deletedAt == nil },
                                           [SortDescriptor(\.name), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.exerciseSettings = try fetch(StoredExerciseSettings.self, #Predicate { $0.deletedAt == nil },
                                              [SortDescriptor(\.createdAt), SortDescriptor(\.id)]).map { $0.toDomain() }
        // Les séances Pulse (magasin synchronisé) et les séances importées d'Apple Health (magasin local), fusionnées ;
        // les courses Pulse retrouvent leur FC et leur RPE estimé dans le résumé local.
        let syncedRows = try fetch(StoredWorkoutSession.self, #Predicate { $0.deletedAt == nil },
                                   [SortDescriptor(\.startedAt), SortDescriptor(\.createdAt)])
        let synced = try RunHealthSummaryJoin.fill(syncedRows.map { $0.toDomain() }, in: modelContext)
        let imported = try fetch(StoredImportedWorkout.self, #Predicate { $0.deletedAt == nil },
                                 [SortDescriptor(\.startedAt), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.workoutSessions = (synced + imported).sorted { ($0.startedAt, $0.createdAt) < ($1.startedAt, $1.createdAt) }
        snapshot.runTracks = try runTracks()
        snapshot.sessionPhotos = try fetch(StoredSessionPhoto.self, #Predicate { $0.deletedAt == nil },
                                           [SortDescriptor(\.createdAt), SortDescriptor(\.order), SortDescriptor(\.id)])
            .map { $0.toDomain() }
        snapshot.scheduledDays = try fetch(StoredScheduledDay.self, #Predicate { $0.deletedAt == nil },
                                           [SortDescriptor(\.date), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        // Les valeurs brutes d'Apple Health viennent du magasin local, recollées sur chaque score.
        let recoveries = try fetch(StoredDailyRecovery.self, #Predicate { $0.deletedAt == nil },
                                   [SortDescriptor(\.day)]).map { $0.toDomain() }
        let readings = try fetch(StoredRecoveryReading.self, #Predicate { _ in true }, [SortDescriptor(\.day)])
        snapshot.dailyRecoveries = RecoveryReadingJoin.fill(recoveries, with: readings)
        snapshot.checkIns = try fetch(StoredCheckIn.self, #Predicate { $0.deletedAt == nil }, [SortDescriptor(\.day)])
            .map { $0.toDomain() }
        snapshot.supplements = try fetch(StoredSupplement.self, #Predicate { $0.deletedAt == nil },
                                         [SortDescriptor(\.order), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.supplementIntakes = try fetch(StoredSupplementIntake.self, #Predicate { $0.deletedAt == nil },
                                               [SortDescriptor(\.takenAt), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        let manual = try fetch(StoredBodyMeasurement.self, #Predicate { $0.deletedAt == nil },
                               [SortDescriptor(\.date), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        let healthMeasures = try fetch(StoredImportedBodyMeasurement.self, #Predicate { $0.deletedAt == nil },
                                       [SortDescriptor(\.date), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.bodyMeasurements = (manual + healthMeasures).sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
        snapshot.personalRecords = try fetch(StoredPersonalRecord.self, #Predicate { $0.deletedAt == nil },
                                             [SortDescriptor(\.date, order: .reverse)]).map { $0.toDomain() }
        return snapshot
    }

    /// Un tracé par séance : si deux appareils en ont créé chacun un (pas de clé unique côté CloudKit), le plus récent.
    private func runTracks() throws -> [RunTrack] {
        let rows = try fetch(StoredRunTrack.self, #Predicate { $0.deletedAt == nil }, [SortDescriptor(\.updatedAt, order: .reverse)])
        var seen = Set<UUID>()
        return rows.filter { seen.insert($0.id).inserted }.map { $0.toDomain() }
            .sorted { $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString }
    }

    /// Les octets de l'image d'une photo vivante, lus un par un pour ne jamais tenir toutes les photos en mémoire.
    /// Nil si la photo est supprimée ou si son image n'est pas encore descendue d'iCloud.
    public func imageData(ofPhoto photoID: UUID) throws -> Data? {
        var descriptor = FetchDescriptor<StoredSessionPhoto>(predicate: #Predicate { $0.id == photoID && $0.deletedAt == nil },
                                                             sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.imageData
    }

    private func fetch<T: PersistentModel>(_ type: T.Type, _ predicate: Predicate<T>, _ sort: [SortDescriptor<T>]) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>(predicate: predicate, sortBy: sort))
    }
}
