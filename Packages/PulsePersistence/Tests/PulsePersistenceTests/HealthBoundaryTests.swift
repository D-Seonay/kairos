import Foundation
import PulseDomain
@testable import PulsePersistence
import SwiftData
import Testing

/// Frontière de confidentialité (M8a) : aucune valeur Apple Health ne reste dans le magasin synchronisé avec iCloud.
@Test func syncedStoreHoldsNoHealthValue() async throws {
    let box = try ModelContainerBox()
    try await SwiftDataRecoveryRepository(modelContainer: box.container, calendar: Fixed.calendar).save(Sample.recovery())
    let workouts = SwiftDataWorkoutRepository(modelContainer: box.container)
    try await workouts.save(Sample.importedRun())
    try await workouts.save(Sample.session())
    try await SwiftDataBodyMeasurementRepository(modelContainer: box.container).save(Sample.measurement())
    let context = ModelContext(box.container)
    let recoveries = try context.fetch(FetchDescriptor<StoredDailyRecovery>())
    #expect(recoveries.allSatisfy { $0.sdnnMs == nil && $0.sdnnBaselineMs == nil && $0.restingHeartRate == nil
        && $0.restingHeartRateBaseline == nil && $0.asleepMinutes == nil && $0.deepMinutes == nil })
    let health = SessionSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredWorkoutSession>(predicate: #Predicate { $0.source == health })) == 0)
    let healthMeasure = MeasurementSource.appleHealth.rawValue
    #expect(try context.fetchCount(FetchDescriptor<StoredBodyMeasurement>(predicate: #Predicate { $0.source == healthMeasure })) == 0)
}
