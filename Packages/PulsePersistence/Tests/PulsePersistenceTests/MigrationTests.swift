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

@Test func v3StoreOpensAsV4KeepingData() async throws {
    let directory = try makeStoreDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try writeV3Store(in: directory)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let context = ModelContext(container)
    let recoveries = try context.fetch(FetchDescriptor<StoredDailyRecovery>())
    #expect(recoveries.count == 1)
    #expect(recoveries.first?.sdnnMs == 50)
    let sessions = try context.fetch(FetchDescriptor<StoredWorkoutSession>())
    #expect(sessions.count == 1)
    #expect(sessions.first?.source == SessionSource.appleHealth.rawValue)
    #expect(try context.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 0)
}

@Test func v4StoreOpensAsV5KeepingData() async throws {
    let directory = try makeStoreDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let pulseID = try writeV4Store(in: directory)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    let sessions = try await workouts.sessions(from: .distantPast, to: .distantFuture)
    #expect(sessions.map(\.source) == [.pulse, .appleHealth])
    #expect(sessions.first?.id == pulseID && sessions.last?.averageHeartRate == 151)
    let context = ModelContext(container)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunTrack>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunDraft>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<StoredRunHealthSummary>()) == 0)
    let tracks = SwiftDataRunTrackRepository(modelContainer: container)
    try await tracks.save(Sample.runTrack(sessionID: pulseID))
    #expect(try await tracks.track(for: pulseID)?.points.count == 4)
}

@Test func v5StoreOpensAsV6KeepingData() async throws {
    let directory = try makeStoreDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let pulseID = try writeV5Store(in: directory)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    let sessions = try await workouts.sessions(from: .distantPast, to: .distantFuture)
    #expect(sessions.map(\.id) == [pulseID])
    let tracks = SwiftDataRunTrackRepository(modelContainer: container)
    #expect(try await tracks.track(for: pulseID)?.points.count == 4)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredSessionPhoto>()) == 0)
    let photos = SwiftDataSessionPhotoRepository(modelContainer: container)
    let photo = Sample.sessionPhoto(sessionID: pulseID, order: 0)
    try await photos.add(photo, image: Sample.photoImage(seed: 7))
    #expect(try await photos.photos(for: pulseID).map(\.id) == [photo.id])
    #expect(try await photos.image(of: photo.id) == Sample.photoImage(seed: 7))
}

@Test func v7StoreOpensAsV8KeepingProfile() async throws {
    let directory = try makeStoreDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let knownID = UUID()
    try writeV7Store(in: directory, profileID: knownID)

    let container = try PersistenceStack.makeContainer(directory: directory)
    let profile = try #require(try await SwiftDataProfileRepository(modelContainer: container).load())
    #expect(profile.id == knownID && profile.firstName == "Mathéo")
    #expect(profile.sleepGoalMinutes == nil && profile.weekdayWakeMinutes == nil && profile.weekendWakeMinutes == nil)
    #expect(profile.bedtimeReminderEnabled == false && profile.bedtimeReminderLeadMinutes == nil)
}

private func makeStoreDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// Les modèles synchronisés de la V2, avec les copies figées des six modèles modifiés en V3, du profil modifié en V8 et du score
/// et du check-in modifiés en V9.
private let v2SyncedModels: [any PersistentModel.Type] = [
    PulseSchemaV7.StoredProfile.self, PulseSchemaV2.StoredProgram.self, PulseSchemaV2.StoredRoutineDay.self,
    PulseSchemaV2.StoredRoutineExercise.self, PulseSchemaV2.StoredUserExercise.self, PulseSchemaV2.StoredWorkoutSession.self,
    PulseSchemaV2.StoredWorkoutSet.self, StoredScheduledDay.self, PulseSchemaV8.StoredDailyRecovery.self,
    PulseSchemaV8.StoredCheckIn.self, StoredSupplement.self, StoredSupplementIntake.self, StoredBodyMeasurement.self,
    StoredPersonalRecord.self
]

/// Les modèles locaux d'avant la V4.
private let v3LocalModels: [any PersistentModel.Type] = [
    StoredCachedHealthSample.self, StoredHealthQueryAnchor.self, StoredActiveSessionSnapshot.self
]

/// Ouvre un conteneur sans plan de migration sur `synced.store` et `local.store` de `directory`, pour une version figée.
private func makeFrozenContainer(_ version: any VersionedSchema.Type, synced: [any PersistentModel.Type],
                                 local: [any PersistentModel.Type] = v3LocalModels, in directory: URL) throws -> ModelContainer {
    let configurations = [
        ModelConfiguration("synced", schema: Schema(synced), url: directory.appending(path: "synced.store"),
                           cloudKitDatabase: .none),
        ModelConfiguration("local", schema: Schema(local), url: directory.appending(path: "local.store"),
                           cloudKitDatabase: .none)
    ]
    return try ModelContainer(for: Schema(versionedSchema: version), configurations: configurations)
}

/// Écrit un magasin sur disque avec le schéma V1, puis relâche le conteneur à la sortie.
private func writeV1Store(in directory: URL, profileID: UUID) throws {
    let synced: [any PersistentModel.Type] = [
        PulseSchemaV1.StoredProfile.self, PulseSchemaV2.StoredProgram.self, PulseSchemaV2.StoredRoutineDay.self,
        PulseSchemaV2.StoredRoutineExercise.self, PulseSchemaV2.StoredUserExercise.self, PulseSchemaV2.StoredWorkoutSession.self,
        PulseSchemaV2.StoredWorkoutSet.self, StoredScheduledDay.self, PulseSchemaV1.StoredDailyRecovery.self,
        PulseSchemaV8.StoredCheckIn.self,
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

/// Écrit un magasin V3 : une récupération avec un SDNN de 50 et une séance importée d'Apple Health.
private func writeV3Store(in directory: URL) throws {
    let container = try makeFrozenContainer(PulseSchemaV3.self, synced: PulseSchemaV4.syncedModels, in: directory)
    let context = ModelContext(container)
    let recovery = PulseSchemaV8.StoredDailyRecovery()
    recovery.day = Fixed.calendar.startOfDay(for: Fixed.t0)
    recovery.score = 60
    recovery.createdAt = Fixed.t0
    recovery.updatedAt = Fixed.t0
    recovery.sdnnMs = 50   // l'ancienne ligne V3 porte encore la valeur brute
    context.insert(recovery)
    let session = StoredWorkoutSession(WorkoutSession(startedAt: Fixed.t0, kind: .run, source: .appleHealth, status: .completed,
                                                      title: "Course", createdAt: Fixed.t0, updatedAt: Fixed.t0))
    context.insert(session)
    try context.save()
}

/// Écrit un magasin V4 : une séance Pulse dans le magasin synchronisé et une course importée dans le magasin local.
/// Renvoie l'identifiant de la séance Pulse.
private func writeV4Store(in directory: URL) throws -> UUID {
    let container = try makeFrozenContainer(PulseSchemaV4.self, synced: PulseSchemaV4.syncedModels,
                                            local: PulseSchemaV4.localModels, in: directory)
    let context = ModelContext(container)
    let session = Sample.session(sets: 2)
    context.insert(StoredWorkoutSession(session))
    context.insert(StoredImportedWorkout(Sample.importedRun(startedAt: Fixed.t0.addingTimeInterval(86_400))))
    try context.save()
    return session.id
}

/// Écrit un magasin V5 : une séance Pulse et son tracé de course.
private func writeV5Store(in directory: URL) throws -> UUID {
    let container = try makeFrozenContainer(PulseSchemaV5.self, synced: PulseSchemaV5.syncedModels,
                                            local: PulseSchemaV5.localModels, in: directory)
    let context = ModelContext(container)
    let run = Sample.pulseRun()
    context.insert(StoredWorkoutSession(run))
    context.insert(StoredRunTrack(Sample.runTrack(sessionID: run.id)))
    try context.save()
    return run.id
}

/// Écrit un magasin V7 : un profil figé avec un prénom, sans réglage de sommeil.
private func writeV7Store(in directory: URL, profileID: UUID) throws {
    let container = try makeFrozenContainer(PulseSchemaV7.self, synced: PulseSchemaV7.syncedModels,
                                            local: PulseSchemaV8.localModels, in: directory)
    let context = ModelContext(container)
    let profile = PulseSchemaV7.StoredProfile()
    profile.id = profileID
    profile.firstName = "Mathéo"
    profile.createdAt = Fixed.t0
    context.insert(profile)
    try context.save()
}
