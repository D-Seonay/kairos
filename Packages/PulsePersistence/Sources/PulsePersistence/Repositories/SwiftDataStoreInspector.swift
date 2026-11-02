import CloudKit
import Foundation
import PulseDomain
import SwiftData

/// Comptes par table et état du compte iCloud, pour l'écran de debug.
public struct SwiftDataStoreInspector: StoreInspector {
    private let counter: StoreCounter
    private let cloudEnabled: Bool

    /// `cloudEnabled` faux : aucun appel CloudKit (un conteneur sans entitlement iCloud fait planter le processus).
    public init(container: ModelContainer, cloudEnabled: Bool) {
        counter = StoreCounter(modelContainer: container)
        self.cloudEnabled = cloudEnabled
    }

    public func counts() async throws -> [StoreTable: Int] {
        try await counter.counts()
    }

    public func cloudAccountStatus() async -> CloudAccountStatus {
        guard cloudEnabled else { return .unknown }
        let status = try? await CKContainer(identifier: PersistenceStack.cloudContainerIdentifier).accountStatus()
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        default: return .unknown
        }
    }
}

@ModelActor
actor StoreCounter {
    private typealias Counter = @Sendable (ModelContext) throws -> Int

    /// Enregistrements non supprimés des tables synchronisées ; les tables locales n'ont pas de `deletedAt`.
    private static let counters: [StoreTable: Counter] = [
        .profile: { try live(StoredProfile.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .programs: { try live(StoredProgram.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .routineDays: { try live(StoredRoutineDay.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .routineExercises: { try live(StoredRoutineExercise.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .userExercises: { try live(StoredUserExercise.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .exerciseSettings: { try live(StoredExerciseSettings.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .workoutSessions: { try live(StoredWorkoutSession.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .workoutSets: { try live(StoredWorkoutSet.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .scheduledDays: { try live(StoredScheduledDay.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .dailyRecoveries: { try live(StoredDailyRecovery.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .checkIns: { try live(StoredCheckIn.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .supplements: { try live(StoredSupplement.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .supplementIntakes: { try live(StoredSupplementIntake.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .bodyMeasurements: { try live(StoredBodyMeasurement.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .personalRecords: { try live(StoredPersonalRecord.self, #Predicate { $0.deletedAt == nil }, in: $0) },
        .cachedHealthSamples: { try $0.fetchCount(FetchDescriptor<StoredCachedHealthSample>()) },
        .healthQueryAnchors: { try $0.fetchCount(FetchDescriptor<StoredHealthQueryAnchor>()) },
        .activeSessionSnapshots: { try $0.fetchCount(FetchDescriptor<StoredActiveSessionSnapshot>()) }
    ]

    func counts() throws -> [StoreTable: Int] {
        var counts: [StoreTable: Int] = [:]
        for table in StoreTable.allCases {
            counts[table] = try Self.counters[table]?(modelContext) ?? 0
        }
        return counts
    }

    private static func live<T: PersistentModel>(_ type: T.Type, _ predicate: Predicate<T>, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>(predicate: predicate))
    }
}
