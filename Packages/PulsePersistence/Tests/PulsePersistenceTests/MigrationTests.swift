import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

@Test func v1StoreOpensAsV3KeepingData() async throws {
    let directory = try makeStoreDirectory()
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

@Test func v2StoreWithProgramAndSessionsOpensAsV3() async throws {
    let directory = try makeStoreDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try writeV2Store(in: directory)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let program = try #require(try await SwiftDataProgramRepository(modelContainer: container).programs(includeArchived: false).first)
    #expect(program.days.map(\.name) == ["Jour 1", "Jour 2"])
    #expect(program.days[0].exercises.map(\.order) == [0, 1, 2])
    #expect(program.days[0].exercises[1].supersetGroup == 1)
    #expect(program.days[0].exercises.allSatisfy { $0.setTargets == nil })
    let sessions = try await SwiftDataWorkoutRepository(modelContainer: container).sessions(from: .distantPast, to: .distantFuture)
    let session = try #require(sessions.first)
    #expect(session.sets.count == 9)
    #expect(session.exerciseNotes.isEmpty)
    #expect(session.sets.allSatisfy { $0.durationSeconds == nil })
    let user = try #require(try await SwiftDataUserExerciseRepository(modelContainer: container).all(includeArchived: false).first)
    #expect(user.loadKind == .external && user.isCompound == false && user.tracksDuration == false)
}

private func makeStoreDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Les modèles synchronisés de la V2, avec les copies figées des six modèles modifiés en V3.
private let v2SyncedModels: [any PersistentModel.Type] = [
    StoredProfile.self, PulseSchemaV2.StoredProgram.self, PulseSchemaV2.StoredRoutineDay.self,
    PulseSchemaV2.StoredRoutineExercise.self, PulseSchemaV2.StoredUserExercise.self, PulseSchemaV2.StoredWorkoutSession.self,
    PulseSchemaV2.StoredWorkoutSet.self, StoredScheduledDay.self, StoredDailyRecovery.self, StoredCheckIn.self,
    StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self, StoredPersonalRecord.self
]

/// Ouvre un conteneur sans plan de migration sur `synced.store` et `local.store` de `directory`, pour une version figée.
private func makeFrozenContainer(_ version: any VersionedSchema.Type, synced: [any PersistentModel.Type],
                                 in directory: URL) throws -> ModelContainer {
    let configurations = [
        ModelConfiguration("synced", schema: Schema(synced), url: directory.appending(path: "synced.store"),
                           cloudKitDatabase: .none),
        ModelConfiguration("local", schema: Schema(PersistenceStack.localModels), url: directory.appending(path: "local.store"),
                           cloudKitDatabase: .none)
    ]
    return try ModelContainer(for: Schema(versionedSchema: version), configurations: configurations)
}

/// Écrit un magasin sur disque avec le schéma V1, puis relâche le conteneur à la sortie.
private func writeV1Store(in directory: URL, profileID: UUID) throws {
    let synced: [any PersistentModel.Type] = [
        PulseSchemaV1.StoredProfile.self, PulseSchemaV2.StoredProgram.self, PulseSchemaV2.StoredRoutineDay.self,
        PulseSchemaV2.StoredRoutineExercise.self, PulseSchemaV2.StoredUserExercise.self, PulseSchemaV2.StoredWorkoutSession.self,
        PulseSchemaV2.StoredWorkoutSet.self, StoredScheduledDay.self, PulseSchemaV1.StoredDailyRecovery.self, StoredCheckIn.self,
        StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self, StoredPersonalRecord.self
    ]
    let container = try makeFrozenContainer(PulseSchemaV1.self, synced: synced, in: directory)
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

/// Écrit un magasin V2 : un programme de 2 jours × 3 exercices (dont un super set), une séance de 9 séries, un exercice perso.
private func writeV2Store(in directory: URL) throws {
    let container = try makeFrozenContainer(PulseSchemaV2.self, synced: v2SyncedModels, in: directory)
    let context = ModelContext(container)
    let program = PulseSchemaV2.StoredProgram()
    program.name = "Programme"
    program.sessionsPerWeek = 2
    context.insert(program)
    for dayIndex in 0..<2 {
        let day = PulseSchemaV2.StoredRoutineDay()
        day.order = dayIndex
        day.name = "Jour \(dayIndex + 1)"
        day.program = program
        context.insert(day)
        for order in 0..<3 {
            let exercise = PulseSchemaV2.StoredRoutineExercise()
            exercise.order = order
            exercise.contentExerciseID = "bench-press-barbell"
            exercise.supersetGroup = order == 0 ? nil : 1
            exercise.day = day
            context.insert(exercise)
        }
    }
    insertV2Session(in: context)
    let user = PulseSchemaV2.StoredUserExercise()
    user.name = "Rowing machine du coin"
    context.insert(user)
    try context.save()
}

private func insertV2Session(in context: ModelContext) {
    let session = PulseSchemaV2.StoredWorkoutSession()
    session.startedAt = Fixed.t0
    session.status = SessionStatus.completed.rawValue
    context.insert(session)
    for order in 1...9 {
        let set = PulseSchemaV2.StoredWorkoutSet()
        set.order = order
        set.contentExerciseID = "bench-press-barbell"
        set.exerciseName = "Développé couché"
        set.actualWeightKg = 80
        set.actualReps = 8
        set.session = session
        context.insert(set)
    }
}
