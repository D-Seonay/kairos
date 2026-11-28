import Foundation
import HealthKit
import PulseDomain

/// L'écriture réelle des séances dans Apple Santé (spec M4 §19.5) : un entraînement `traditionalStrengthTraining` avec son
/// énergie estimée, et l'effacement de tout ce que Pulse y a écrit (spec M2 §7.2). Les prises de compléments sont dans
/// l'extension `+Supplements` (spec M5 §6). `HKHealthStore` est thread-safe, d'où `@unchecked Sendable`.
public final class HealthKitWorkoutWriter: WorkoutHealthWriting, HealthErasing, @unchecked Sendable {
    let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    /// Les types que Pulse écrit : l'entraînement et son énergie active, et pour une course sa distance GPS et son tracé.
    static var shared: Set<HKSampleType> {
        [HKWorkoutType.workoutType(), HKQuantityType(.activeEnergyBurned), HKSeriesType.workoutRoute(),
         HKQuantityType(.distanceWalkingRunning)]
    }

    // MARK: - WorkoutHealthWriting

    public func writeAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKWorkoutType.workoutType()) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .denied
        }
    }

    public func requestWriteAccess() async -> HealthWriteAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // Une demande refusée ou interrompue n'empêche rien : l'état relu dit ce qui est permis.
        do {
            try await store.requestAuthorization(toShare: Self.shared, read: [])
        } catch {
            logger.failure("Demande d'écriture Apple Santé en échec", error)
        }
        return await writeAccess()
    }

    public func save(_ entry: StrengthWorkoutEntry) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: entry.start)
        if let kcal = entry.energyKcal, kcal > 0 {
            let energy = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                          quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                          start: entry.start, end: entry.end)
            try await builder.addSamples([energy])
        }
        try await builder.addMetadata([HKMetadataKeyExternalUUID: entry.sessionID.uuidString])
        try await builder.endCollection(at: entry.end)
        guard let workout = try await builder.finishWorkout() else { throw WriteError.notSaved }
        return workout.uuid
    }

    public func deleteWorkout(id: UUID) async throws {
        guard await writeAccess() == .authorized else { return }
        let ownWorkout = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObject(with: id), HKQuery.predicateForObjects(from: HKSource.default())
        ])
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(ownWorkout)], sortDescriptors: [])
        for workout in try await descriptor.result(for: store) {
            try await deleteObjects(of: HKQuantityType(.activeEnergyBurned), matching: HKQuery.predicateForObjects(from: workout))
            try await store.delete(workout)
        }
    }

    // MARK: - HealthErasing

    /// Supprime les entraînements, l'énergie, les distances et tracés de course et les prises de compléments écrits par Pulse.
    /// Sans accès en écriture à un type, Pulse n'a rien pu y écrire.
    public func deleteAllSamplesWrittenByPulse() async throws {
        try await deleteAllSupplementSamples()
        guard await writeAccess() == .authorized else { return }
        let fromPulse = HKQuery.predicateForObjects(from: HKSource.default())
        let runTypes: [HKObjectType] = [HKSeriesType.workoutRoute(), HKQuantityType(.distanceWalkingRunning)]
        for type in runTypes where store.authorizationStatus(for: type) == .sharingAuthorized {
            try await deleteObjects(of: type, matching: fromPulse)
        }
        for type in [HKQuantityType(.activeEnergyBurned), HKWorkoutType.workoutType()] as [HKObjectType] {
            try await deleteObjects(of: type, matching: fromPulse)
        }
    }

    // MARK: - Interne

    enum WriteError: Error {
        case notSaved
    }

    func deleteObjects(of type: HKObjectType, matching predicate: NSPredicate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            store.deleteObjects(of: type, predicate: predicate) { _, _, error in
                // Rien à supprimer n'est pas un échec.
                if let error, (error as? HKError)?.code != .errorNoData {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
