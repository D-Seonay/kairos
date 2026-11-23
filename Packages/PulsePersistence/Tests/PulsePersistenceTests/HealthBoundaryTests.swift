import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

// `UserProfile.weightKg` est couvert par WeightTrendTests (PulseFeatures) : PulsePersistence n'atteint pas `ProfileWeightSync`.
/// Frontière de confidentialité (M8a) : aucune valeur Apple Health ne reste dans le magasin synchronisé avec iCloud.
@Test func syncedStoreHoldsNoHealthValue() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    let workouts = SwiftDataWorkoutRepository(modelContainer: box.container)
    try await workouts.save(Sample.importedRun())
    try await workouts.save(Sample.session())
    try await workouts.save(Sample.pulseRun())
    try await SwiftDataBodyMeasurementRepository(modelContainer: box.container).save(Sample.measurement())
    let context = ModelContext(box.container)
    let recoveries = try context.fetch(FetchDescriptor<StoredDailyRecovery>())
    #expect(recoveries.allSatisfy { $0.sdnnMs == nil && $0.sdnnBaselineMs == nil && $0.restingHeartRate == nil
        && $0.restingHeartRateBaseline == nil && $0.asleepMinutes == nil && $0.deepMinutes == nil })
    let health = SessionSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate { $0.source == health })) == 0)
    // Une course Pulse reste synchronisée, mais sans sa FC ni son RPE estimé (frontière M8).
    let pulse = SessionSource.pulse.rawValue
    let run = SessionKind.run.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(
        predicate: #Predicate { $0.source == pulse && $0.kind == run })) == 1)
    #expect(try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate {
        $0.source == pulse && $0.kind == run && ($0.averageHeartRate != nil || $0.estimatedRPE != nil)
    })) == 0)
    let healthMeasure = MeasurementSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredBodyMeasurement>(predicate: #Predicate { $0.source == healthMeasure })) == 0)
}

/// Clés uniques des modèles locaux (Review M8a, point 2) : deux lignes de même clé enregistrées ensemble n'en font qu'une.
@Test func localHealthModelsKeepOneRowPerKey() throws {
    let box = try ModelContainerBox()
    let context = ModelContext(box.container)
    let day = Fixed.calendar.startOfDay(for: Fixed.t0)
    context.insert(StoredRecoveryReading(day: day, from: Sample.recovery(day: day), at: Fixed.t1))
    context.insert(StoredRecoveryReading(day: day, from: Sample.recovery(day: day), at: Fixed.t2))
    let run = Sample.importedRun()
    context.insert(StoredImportedWorkout(run))
    context.insert(StoredImportedWorkout(run))
    let weighIn = Sample.measurement()
    context.insert(StoredImportedBodyMeasurement(weighIn))
    context.insert(StoredImportedBodyMeasurement(weighIn))
    try context.save()
    let check = ModelContext(box.container)
    #expect(try check.fetchCount(FetchDescriptor<StoredRecoveryReading>()) == 1)
    #expect(try check.fetchCount(FetchDescriptor<StoredImportedWorkout>()) == 1)
    #expect(try check.fetchCount(FetchDescriptor<StoredImportedBodyMeasurement>()) == 1)
}

/// Le tracé part dans iCloud ; le brouillon (FC comprises) et le résumé cardio restent dans le magasin local.
@Test func runModelsLiveInTheirStore() throws {
    let container = try TestContainer.make()
    func entities(_ name: String) -> Set<String> {
        Set(container.configurations.first { $0.name == name }?.schema?.entities.map(\.name) ?? [])
    }
    let synced = entities("synced")
    let local = entities("local")
    #expect(synced.contains("StoredRunTrack") && !local.contains("StoredRunTrack"))
    #expect(local.contains("StoredRunDraft") && !synced.contains("StoredRunDraft"))
    #expect(local.contains("StoredRunHealthSummary") && !synced.contains("StoredRunHealthSummary"))
}
