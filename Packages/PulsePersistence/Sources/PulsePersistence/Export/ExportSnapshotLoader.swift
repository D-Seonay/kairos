import Foundation
import PulseDomain
import SwiftData

/// Toutes les données exportables, lues en une fois.
public struct ExportSnapshot: Sendable {
    public var profile: UserProfile?
    public var programs: [Program] = []
    public var userExercises: [UserExercise] = []
    public var workoutSessions: [WorkoutSession] = []
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
        snapshot.workoutSessions = try fetch(StoredWorkoutSession.self, #Predicate { $0.deletedAt == nil },
                                             [SortDescriptor(\.startedAt), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.scheduledDays = try fetch(StoredScheduledDay.self, #Predicate { $0.deletedAt == nil },
                                           [SortDescriptor(\.date), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.dailyRecoveries = try fetch(StoredDailyRecovery.self, #Predicate { $0.deletedAt == nil },
                                             [SortDescriptor(\.day)]).map { $0.toDomain() }
        snapshot.checkIns = try fetch(StoredCheckIn.self, #Predicate { $0.deletedAt == nil }, [SortDescriptor(\.day)])
            .map { $0.toDomain() }
        snapshot.supplements = try fetch(StoredSupplement.self, #Predicate { $0.deletedAt == nil },
                                         [SortDescriptor(\.order), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.supplementIntakes = try fetch(StoredSupplementIntake.self, #Predicate { $0.deletedAt == nil },
                                               [SortDescriptor(\.takenAt), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.bodyMeasurements = try fetch(StoredBodyMeasurement.self, #Predicate { $0.deletedAt == nil },
                                              [SortDescriptor(\.date), SortDescriptor(\.createdAt)]).map { $0.toDomain() }
        snapshot.personalRecords = try fetch(StoredPersonalRecord.self, #Predicate { $0.deletedAt == nil },
                                             [SortDescriptor(\.date, order: .reverse)]).map { $0.toDomain() }
        return snapshot
    }

    private func fetch<T: PersistentModel>(_ type: T.Type, _ predicate: Predicate<T>, _ sort: [SortDescriptor<T>]) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>(predicate: predicate, sortBy: sort))
    }
}
