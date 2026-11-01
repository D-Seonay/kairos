import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func v1StoreOpensAsV2KeepingData() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let knownID = UUID()
    try writeV1Store(in: directory, profileID: knownID)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let profile = try await SwiftDataProfileRepository(modelContainer: container).load()
    #expect(profile?.id == knownID)
    #expect(profile?.firstName == nil)
    let recoveries = try await SwiftDataRecoveryRepository(modelContainer: container, calendar: Fixed.calendar)
        .dailyRecoveries(from: .distantPast, to: .distantFuture)
    #expect(recoveries.map(\.score) == [58])
    #expect(recoveries.first?.originalSessionChosen == nil)
}

/// Écrit un magasin sur disque avec le schéma V1, puis relâche le conteneur à la sortie.
private func writeV1Store(in directory: URL, profileID: UUID) throws {
    let synced: [any PersistentModel.Type] = [
        PulseSchemaV1.StoredProfile.self, StoredProgram.self, StoredRoutineDay.self, StoredRoutineExercise.self,
        StoredUserExercise.self, StoredWorkoutSession.self, StoredWorkoutSet.self, StoredScheduledDay.self,
        PulseSchemaV1.StoredDailyRecovery.self, StoredCheckIn.self, StoredSupplement.self, StoredSupplementIntake.self,
        StoredBodyMeasurement.self, StoredPersonalRecord.self
    ]
    let configurations = [
        ModelConfiguration("synced", schema: Schema(synced), url: directory.appending(path: "synced.store"),
                           cloudKitDatabase: .none),
        ModelConfiguration("local", schema: Schema(PersistenceStack.localModels), url: directory.appending(path: "local.store"),
                           cloudKitDatabase: .none)
    ]
    let container = try ModelContainer(for: Schema(versionedSchema: PulseSchemaV1.self), configurations: configurations)
    let context = ModelContext(container)
    let profile = PulseSchemaV1.StoredProfile()
    profile.id = profileID
    profile.createdAt = Fixed.t0
    context.insert(profile)
    let recovery = PulseSchemaV1.StoredDailyRecovery()
    recovery.day = Fixed.calendar.startOfDay(for: Fixed.t0)
    recovery.score = 58
    context.insert(recovery)
    try context.save()
}
