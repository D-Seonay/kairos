import Foundation
import PulseDomain
@testable import PulsePersistence
import Testing

@Test func inspectorCountsEveryTable() async throws {
    let container = try TestContainer.make()
    let inspector = SwiftDataStoreInspector(container: container, cloudEnabled: false)
    #expect(await inspector.cloudAccountStatus() == .unknown)
    try await SwiftDataProfileRepository(modelContainer: container).save(UserProfile())
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    try await workouts.save(Sample.session(sets: 3))
    let deleted = Sample.session(sets: 2)
    try await workouts.save(deleted)
    try await workouts.delete(id: deleted.id)
    try await SwiftDataExerciseSettingsRepository(modelContainer: container).save(Sample.exerciseSettings())
    let counts = try await inspector.counts()
    #expect(counts.count == StoreTable.allCases.count)
    #expect(counts[.profile] == 1 && counts[.workoutSessions] == 1 && counts[.workoutSets] == 3)
    #expect(counts[.exerciseSettings] == 1 && counts[.programs] == 0 && counts[.cachedHealthSamples] == 0)
}

@Test func countsIncludeLocalImports() async throws {
    let container = try TestContainer.make()
    let workouts = SwiftDataWorkoutRepository(modelContainer: container)
    try await workouts.save(Sample.session(sets: 1))
    try await workouts.save(Sample.importedRun())
    let measurements = SwiftDataBodyMeasurementRepository(modelContainer: container)
    var manual = Sample.measurement()
    manual.source = .manual
    manual.healthKitUUID = nil
    try await measurements.save(manual)
    try await measurements.save(Sample.measurement())
    let counts = try await SwiftDataStoreInspector(container: container, cloudEnabled: false).counts()
    #expect(counts[.workoutSessions] == 2 && counts[.bodyMeasurements] == 2)
}

@Test func countsIncludeRunModels() async throws {
    let container = try TestContainer.make()
    let run = Sample.pulseRun()
    try await SwiftDataWorkoutRepository(modelContainer: container).save(run)
    let tracks = SwiftDataRunTrackRepository(modelContainer: container)
    try await tracks.save(Sample.runTrack(sessionID: run.id))
    let deleted = Sample.runTrack()
    try await tracks.save(deleted)
    try await tracks.delete(sessionID: deleted.id)
    try await SwiftDataRunDraftStore(modelContainer: container).save(Sample.runDraft())
    let counts = try await SwiftDataStoreInspector(container: container, cloudEnabled: false).counts()
    #expect(counts[.runTracks] == 1 && counts[.runDrafts] == 1 && counts[.runHealthSummaries] == 1)
}
