import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

private let day: TimeInterval = 86_400

@Test func sessionsFilterByRangeAndSortAscending() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let late = Sample.session(startedAt: Fixed.t0.addingTimeInterval(2 * day), sets: 1)
    let early = Sample.session(startedAt: Fixed.t0, sets: 1)
    let outside = Sample.session(startedAt: Fixed.t0.addingTimeInterval(5 * day), sets: 1)
    for session in [late, early, outside] { try await repo.save(session) }
    let found = try await repo.sessions(from: Fixed.t0, to: Fixed.t0.addingTimeInterval(5 * day))
    #expect(found.map(\.id) == [early.id, late.id])
    try await repo.delete(id: early.id)
    #expect(try await repo.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [late.id, outside.id])
}

@Test func saveSessionUpdatesSetsInPlace() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    var session = Sample.session(sets: 3)
    try await repo.save(session)
    session.sets[1].actualReps = 12
    session.sets.removeLast()
    let before = Date()
    try await repo.save(session)
    let loaded = try #require(try await repo.session(id: session.id))
    #expect(loaded.sets.count == 2 && loaded.sets[1].actualReps == 12 && loaded.updatedAt >= before)
    let context = ModelContext(repo.modelContainer)
    let sets = try context.fetch(FetchDescriptor<StoredWorkoutSet>())
    #expect(sets.count == 3 && sets.filter { $0.deletedAt != nil }.count == 1)
}

@Test func lastSetsReturnsWorkingSetsOfLatestCompletedSession() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let squat = ExerciseReference.content(id: "back-squat-barbell")
    var sessionA = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-3 * day), sets: 0)
    sessionA.sets = [Sample.set(order: 1, exercise: squat, type: .warmup), Sample.set(order: 2, exercise: squat),
                     Sample.set(order: 3, exercise: squat)]
    var sessionB = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-1 * day), sets: 0)
    sessionB.sets = [Sample.set(order: 1), Sample.set(order: 2, exercise: squat), Sample.set(order: 3, exercise: squat),
                     Sample.set(order: 4, exercise: squat)]
    var sessionC = Sample.session(startedAt: Fixed.t0, status: .inProgress, sets: 0)
    sessionC.sets = [Sample.set(order: 1, exercise: squat)]
    for session in [sessionA, sessionB, sessionC] { try await repo.save(session) }
    let sets = try await repo.lastSets(for: squat)
    #expect(sets.count == 3 && sets.allSatisfy { $0.setType == .working } && sets.map(\.order) == [2, 3, 4])
    #expect(try await repo.lastSets(for: .content(id: "unknown")).isEmpty)
}

private func benchSet(order: Int, reps: Int, type: SetType = .working) -> WorkoutSet {
    var set = Sample.set(order: order, type: type)
    set.actualReps = reps
    return set
}

private func benchSession(day offset: Int, status: SessionStatus, sets: [WorkoutSet]) -> WorkoutSession {
    var session = Sample.session(startedAt: Fixed.t0.addingTimeInterval(TimeInterval(offset) * day), status: status, sets: 0)
    session.sets = sets
    return session
}

@Test func lastSetsComeFromTheLatestCompletedOrAbandonedSessionWithoutWarmups() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let completed = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 10, type: .warmup),
                                                                    benchSet(order: 2, reps: 12), benchSet(order: 3, reps: 5)])
    let abandoned = benchSession(day: 9, status: .abandoned, sets: [benchSet(order: 1, reps: 10)])
    let live = benchSession(day: 14, status: .inProgress, sets: [benchSet(order: 1, reps: 8)])
    let deleted = benchSession(day: 15, status: .completed, sets: [benchSet(order: 1, reps: 6)])
    for session in [completed, abandoned, live, deleted] { try await repo.save(session) }
    try await repo.delete(id: deleted.id)

    let bench = ExerciseReference.content(id: "bench-press-barbell")
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [10])
    try await repo.delete(id: abandoned.id)
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [12, 5])
}

@Test func lastSetsStartedBeforeADateIgnoreLaterSessions() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let older = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9), benchSet(order: 2, reps: 7)])
    let newer = benchSession(day: 9, status: .completed, sets: [benchSet(order: 1, reps: 11)])
    for session in [older, newer] { try await repo.save(session) }

    let bench = ExerciseReference.content(id: "bench-press-barbell")
    #expect(try await repo.lastSets(for: bench, startedBefore: newer.startedAt).map(\.actualReps) == [9, 7])
    #expect(try await repo.lastSets(for: bench, startedBefore: older.startedAt).isEmpty)
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [11])
}

@Test func failureAndDropSetsCountAsLastTime() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let session = benchSession(day: 1, status: .completed, sets: [
        benchSet(order: 4, reps: 4, type: .failure), benchSet(order: 1, reps: 10, type: .warmup), benchSet(order: 2, reps: 8),
        benchSet(order: 3, reps: 6, type: .drop)])
    try await repo.save(session)
    let sets = try await repo.lastSets(for: .content(id: "bench-press-barbell"))
    #expect(sets.map(\.setType) == [.working, .drop, .failure] && sets.map(\.order) == [2, 3, 4])
}

@Test func lastSetsFindsAUserExerciseAndIgnoresOtherExercises() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let custom = ExerciseReference.user(id: UUID())
    var session = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9)])
    session.sets.append(Sample.set(order: 2, exercise: custom))
    try await repo.save(session)
    #expect(try await repo.lastSets(for: custom).map(\.order) == [2])
    #expect(try await repo.lastSets(for: .user(id: UUID())).isEmpty)
}

@Test func aNewerSessionWithOnlyWarmupsOfTheExerciseDoesNotHideLastTime() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let older = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9), benchSet(order: 2, reps: 7)])
    let warmupOnly = benchSession(day: 5, status: .abandoned, sets: [benchSet(order: 1, reps: 15, type: .warmup)])
    for session in [older, warmupOnly] { try await repo.save(session) }
    #expect(try await repo.lastSets(for: .content(id: "bench-press-barbell")).map(\.actualReps) == [9, 7])
}

/// Une séance faite en décharge appliquée n'est pas « la dernière fois » ; refusée, elle a été faite aux charges habituelles
/// et compte.
@Test func lastSetsSkipASessionDoneUnderAnAppliedDeload() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let deload = SessionAdjustment(kind: .deload, reason: "Semaine de décharge", value: 0.4)
    let before = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 9), benchSet(order: 2, reps: 7)])
    var deloaded = benchSession(day: 9, status: .completed, sets: [benchSet(order: 1, reps: 11), benchSet(order: 2, reps: 11)])
    deloaded.appliedAdjustments = [SessionAdjustment(kind: .rest, reason: "Repos +15 s", value: 15), deload]
    for session in [before, deloaded] { try await repo.save(session) }
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [9, 7])

    var refused = benchSession(day: 11, status: .completed, sets: [benchSet(order: 1, reps: 6)])
    refused.refusedAdjustments = [deload]
    try await repo.save(refused)
    #expect(try await repo.lastSets(for: bench).map(\.actualReps) == [6])
    try await repo.delete(id: before.id)
    try await repo.delete(id: refused.id)
    #expect(try await repo.lastSets(for: bench).isEmpty, "Sans séance hors décharge, pas de référence")
}

// MARK: - Séances importées d'Apple Health : magasin local

private func counts(_ container: ModelContainer) throws -> (synced: Int, local: Int) {
    let context = ModelContext(container)
    return (try context.fetchCount(FetchDescriptor<StoredWorkoutSession>()),
            try context.fetchCount(FetchDescriptor<StoredImportedWorkout>()))
}

@Test func importedRunLivesOnlyInTheLocalStore() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    try await repo.save(Sample.importedRun())
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 0 && stored.local == 1)
}

@Test func pulseSessionLivesOnlyInTheSyncedStore() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    try await repo.save(Sample.session(sets: 1))
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 1 && stored.local == 0)
}

@Test func sessionsMergeBothStoresInOrder() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let pulse = Sample.session(startedAt: Fixed.t0, sets: 1)
    let run = Sample.importedRun(startedAt: Fixed.t0.addingTimeInterval(-3_600))
    for session in [pulse, run] { try await repo.save(session) }
    #expect(try await repo.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [run.id, pulse.id])
    #expect(try await repo.session(id: run.id)?.id == run.id)
    #expect(try await repo.session(id: pulse.id)?.id == pulse.id)
    #expect(try await repo.session(id: UUID()) == nil)
}

@Test func correctedRunStaysLocal() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let run = Sample.importedRun()
    try await repo.save(run)
    var loaded = try #require(try await repo.session(id: run.id))
    loaded.overallRPE = 8
    loaded.note = "Jambes lourdes"
    try await repo.save(loaded)
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 0 && stored.local == 1)
    let reread = try #require(try await repo.session(id: run.id))
    #expect(reread.overallRPE == 8 && reread.note == "Jambes lourdes")
}

@Test func deletingAnImportedRunMarksItDeleted() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let run = Sample.importedRun()
    let pulse = Sample.session(startedAt: Fixed.t0.addingTimeInterval(day), sets: 1)
    for session in [run, pulse] { try await repo.save(session) }
    try await repo.delete(id: run.id)
    #expect(try await repo.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [pulse.id])
    #expect(try await repo.session(id: run.id) == nil)
    let local = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredImportedWorkout>())
    #expect(local.count == 1 && local[0].deletedAt != nil)
}

@Test func changingSourceMovesTheRowBetweenStores() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    var session = Sample.session(sets: 2)
    try await repo.save(session)
    session.source = .appleHealth
    session.sets = []
    try await repo.save(session)
    let stored = try counts(repo.modelContainer)
    #expect(stored.synced == 0 && stored.local == 1)
    #expect(try await repo.sessions(from: .distantPast, to: .distantFuture).map(\.id) == [session.id])
}

/// Avec la clé unique, réimporter une course supprimée réécrit la même ligne au lieu d'en créer une seconde.
@Test func reimportingADeletedRunReusesItsRow() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let run = Sample.importedRun()
    try await repo.save(run)
    try await repo.delete(id: run.id)
    try await repo.save(run)
    #expect(try counts(repo.modelContainer).local == 1)
    #expect(try await repo.session(id: run.id)?.distanceMeters == 8_000)
}

/// Frontière M8 : la FC et le RPE estimé d'une course Pulse vivent dans le résumé local, jamais dans la ligne synchronisée.
@Test func pulseRunHeartRateStaysLocal() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let run = Sample.pulseRun()
    try await repo.save(run)
    let context = ModelContext(repo.modelContainer)
    let synced = try #require(try context.fetch(FetchDescriptor<StoredWorkoutSession>()).first)
    #expect(synced.averageHeartRate == nil && synced.estimatedRPE == nil)
    let summary = try #require(try context.fetch(FetchDescriptor<StoredRunHealthSummary>()).first)
    #expect(summary.sessionID == run.id && summary.averageHeartRate == 150 && summary.estimatedRPE == 8)
    let loaded = try #require(try await repo.session(id: run.id))
    #expect(loaded.averageHeartRate == 150 && loaded.estimatedRPE == 8)
    let listed = try await repo.sessions(from: .distantPast, to: .distantFuture)
    #expect(listed.map(\.averageHeartRate) == [150] && listed.map(\.estimatedRPE) == [8])
}

@Test func pulseRunSummaryIsUpdatedInPlace() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    var run = Sample.pulseRun()
    try await repo.save(run)
    run.averageHeartRate = 155
    run.estimatedRPE = nil
    try await repo.save(run)
    let summaries = try ModelContext(repo.modelContainer).fetch(FetchDescriptor<StoredRunHealthSummary>())
    #expect(summaries.count == 1 && summaries.first?.averageHeartRate == 155 && summaries.first?.estimatedRPE == nil)
    let loaded = try #require(try await repo.session(id: run.id))
    #expect(loaded.averageHeartRate == 155 && loaded.estimatedRPE == nil)
}

/// Seules les courses Pulse passent par le résumé : une séance de musculation garde ses champs tels quels.
@Test func strengthSessionWritesNoRunSummary() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    try await repo.save(Sample.session(sets: 1))
    #expect(try ModelContext(repo.modelContainer).fetchCount(FetchDescriptor<StoredRunHealthSummary>()) == 0)
}

@Test func deletingAPulseRunRemovesItsSummaryAndTrack() async throws {
    let container = try TestContainer.make()
    let repo = SwiftDataWorkoutRepository(modelContainer: container)
    let tracks = SwiftDataRunTrackRepository(modelContainer: container)
    let run = Sample.pulseRun()
    try await repo.save(run)
    try await tracks.save(Sample.runTrack(sessionID: run.id))
    try await repo.delete(id: run.id)
    #expect(try await repo.session(id: run.id) == nil)
    #expect(try await tracks.track(for: run.id) == nil)
    #expect(try ModelContext(container).fetchCount(FetchDescriptor<StoredRunHealthSummary>()) == 0)
    let tombstone = try #require(try ModelContext(container).fetch(FetchDescriptor<StoredRunTrack>()).first)
    #expect(tombstone.deletedAt != nil && tombstone.points == nil && tombstone.splits == nil && tombstone.elevationGainMeters == nil)
}

@Test func deletingASessionDeletesItsPhotos() async throws {
    let container = try TestContainer.make()
    let repo = SwiftDataWorkoutRepository(modelContainer: container)
    let photos = SwiftDataSessionPhotoRepository(modelContainer: container)
    let session = Sample.session(sets: 1)
    let other = Sample.session(startedAt: Fixed.t1, sets: 1)
    try await repo.save(session)
    try await repo.save(other)
    try await photos.add(Sample.sessionPhoto(sessionID: session.id, order: 0), image: Sample.photoImage(seed: 1))
    try await photos.add(Sample.sessionPhoto(sessionID: session.id, order: 1), image: Sample.photoImage(seed: 2))
    try await photos.add(Sample.sessionPhoto(sessionID: other.id, order: 0), image: Sample.photoImage(seed: 3))
    try await repo.delete(id: session.id)
    #expect(try await photos.photos(for: session.id).isEmpty)
    #expect(try await photos.photos(for: other.id).count == 1)
    let rows = try ModelContext(container).fetch(FetchDescriptor<StoredSessionPhoto>())
    let cleared = rows.filter { $0.sessionID == session.id }
    #expect(cleared.count == 2 && cleared.allSatisfy { $0.deletedAt != nil && $0.imageData == nil && $0.thumbnailData == nil })
    #expect(rows.filter { $0.sessionID == other.id }.allSatisfy { $0.deletedAt == nil && $0.imageData != nil })
}

@Test func completedPulseSessionsAreCountedWithoutTheOthers() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let kept = (0..<3).map { Sample.session(startedAt: Fixed.t0.addingTimeInterval(Double($0) * day), sets: 1) }
    var run = Sample.session(startedAt: Fixed.t0.addingTimeInterval(4 * day), sets: 0)
    run.kind = .run
    var imported = Sample.session(startedAt: Fixed.t0.addingTimeInterval(5 * day), sets: 1)
    imported.source = .hevy
    let abandoned = Sample.session(startedAt: Fixed.t0.addingTimeInterval(6 * day), status: .abandoned, sets: 1)
    let deleted = Sample.session(startedAt: Fixed.t0.addingTimeInterval(7 * day), sets: 1)
    for session in kept + [run, imported, abandoned, deleted] { try await repo.save(session) }
    try await repo.delete(id: deleted.id)
    #expect(try await repo.completedPulseSessionCount(kind: .strength) == 3)
    #expect(try await repo.completedPulseSessionCount(kind: .run) == 1)
}

/// Le début de l'historique d'entraînement : la plus ancienne séance enregistrée, sans les imports d'Apple Santé ni les
/// séances supprimées.
@Test func oldestRecordedStartIgnoresAppleHealthImportsAndDeletedSessions() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    #expect(try await repo.oldestRecordedStart() == nil)
    var importedRun = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-90 * day), sets: 0)
    importedRun.kind = .run
    importedRun.source = .appleHealth
    let deleted = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-30 * day), sets: 1)
    var hevy = Sample.session(startedAt: Fixed.t0.addingTimeInterval(-10 * day), sets: 1)
    hevy.source = .hevy
    let recent = Sample.session(startedAt: Fixed.t0, sets: 1)
    for session in [importedRun, deleted, hevy, recent] { try await repo.save(session) }
    try await repo.delete(id: deleted.id)
    #expect(try await repo.oldestRecordedStart() == hevy.startedAt)
    // La lecture par défaut du protocole, celle des doublures, donne le même jour.
    let all = try await repo.sessions(from: .distantPast, to: .distantFuture)
    #expect(all.filter { $0.source != .appleHealth }.map(\.startedAt).min() == hevy.startedAt)
}

@Test func recentSessionsListTheLatestSessionsWithTheExerciseAndTheirNote() async throws {
    let repo = SwiftDataWorkoutRepository(modelContainer: try TestContainer.make())
    let bench = ExerciseReference.content(id: "bench-press-barbell")
    var old = benchSession(day: 1, status: .completed, sets: [benchSet(order: 1, reps: 10, type: .warmup), benchSet(order: 2, reps: 8)])
    old.exerciseNotes = [ExerciseNote(exercise: bench, text: "Banc cran 3")]
    var deloaded = benchSession(day: 5, status: .abandoned, sets: [benchSet(order: 2, reps: 7), benchSet(order: 1, reps: 9)])
    deloaded.appliedAdjustments = [SessionAdjustment(kind: .deload, reason: "Décharge")]
    deloaded.exerciseNotes = [ExerciseNote(exercise: bench, text: "Prise large")]
    let onlyWarmup = benchSession(day: 7, status: .completed, sets: [benchSet(order: 1, reps: 10, type: .warmup)])
    let live = benchSession(day: 8, status: .inProgress, sets: [benchSet(order: 1, reps: 8)])
    let later = benchSession(day: 20, status: .completed, sets: [benchSet(order: 1, reps: 6)])
    for session in [old, deloaded, onlyWarmup, live, later] { try await repo.save(session) }

    let recent = try await repo.recentSessions(for: bench, startedBefore: Fixed.t0.addingTimeInterval(10 * day), limit: 5)
    #expect(recent.map(\.startedAt) == [deloaded.startedAt, old.startedAt])
    #expect(recent.map(\.isDeloaded) == [true, false])
    #expect(recent.map(\.note) == ["Prise large", "Banc cran 3"])
    #expect(recent[0].sets.map(\.actualReps) == [9, 7] && recent[1].sets.map(\.actualReps) == [8])
    #expect(try await repo.recentSessions(for: bench, startedBefore: .distantFuture, limit: 1).map(\.startedAt) == [later.startedAt])
}
