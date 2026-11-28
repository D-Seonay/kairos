import Foundation
import HealthKit
import PulseDomain

/// La lecture Apple Santé vue par le moteur et les fonctionnalités. Aucune valeur lue n'est journalisée.
extension HealthKitReader: HealthSampleSource, HealthWorkoutSource, HealthBodySource {
    public func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: HealthKitTypes.read)
    }

    /// Une requête ancrée par signal. Une ancre absente ou illisible donne une lecture complète des échantillons postérieurs à `start`.
    public func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        let queryAnchor = anchor.flatMap(Self.decodedAnchor)
        let dates = HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        switch signal {
        case .sdnn:
            return try await quantityChanges(of: signal.kind, .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli),
                                             anchor: queryAnchor, dates: dates)
        case .restingHeartRate:
            return try await quantityChanges(of: signal.kind, .restingHeartRate, unit: Self.beatsPerMinute,
                                             anchor: queryAnchor, dates: dates)
        case .sleep:
            return try await sleepChanges(anchor: queryAnchor, dates: dates)
        }
    }

    /// Chaque indice est lu à part : un refus ou une donnée absente laisse seulement ce champ vide.
    public func profileHints() async throws -> HealthProfileHints {
        HealthProfileHints(
            sex: biologicalSex(),
            birthDate: birthDate(),
            heightCm: await latestQuantity(.height, unit: .meterUnit(with: .centi)),
            weightKg: await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        )
    }

    private func biologicalSex() -> Sex? {
        guard let sex = try? store.biologicalSex().biologicalSex else { return nil }
        switch sex {
        case .female: return .female
        case .male: return .male
        case .other: return .unspecified
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    private func birthDate() -> Date? {
        guard let components = try? store.dateOfBirthComponents() else { return nil }
        return (components.calendar ?? Calendar(identifier: .gregorian)).date(from: components)
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return sample.quantity.doubleValue(for: unit)
    }

    // MARK: - Lectures ancrées

    /// Un échantillon quantitatif est daté de sa fin, comme dans les lectures par période de `HealthReading`.
    private func quantityChanges(of kind: HealthSampleKind, _ identifier: HKQuantityTypeIdentifier, unit: HKUnit, scale: Double = 1,
                                 anchor: HKQueryAnchor?, dates: NSPredicate) async throws -> HealthSampleChanges {
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: dates)], anchor: anchor)
        let result = try await descriptor.result(for: store)
        let added = result.addedSamples.map { sample in
            CachedHealthSample(
                kind: kind, start: sample.endDate, end: sample.endDate, value: sample.quantity.doubleValue(for: unit) * scale,
                healthKitUUID: sample.uuid.uuidString, sourceBundleID: sample.sourceRevision.source.bundleIdentifier,
                fetchedAt: sample.endDate)
        }
        return try Self.changes(of: kind, added: added, deleted: result.deletedObjects, newAnchor: result.newAnchor,
                                isFullRead: anchor == nil)
    }

    private func sleepChanges(anchor: HKQueryAnchor?, dates: NSPredicate) async throws -> HealthSampleChanges {
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: dates)], anchor: anchor)
        let result = try await descriptor.result(for: store)
        let added = result.addedSamples.compactMap { sample -> CachedHealthSample? in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value), let stage = Self.stage(for: value) else { return nil }
            return CachedHealthSample(
                kind: .sleep, start: sample.startDate, end: sample.endDate, sleepStage: stage,
                healthKitUUID: sample.uuid.uuidString, sourceBundleID: sample.sourceRevision.source.bundleIdentifier,
                fetchedAt: sample.endDate)
        }
        return try Self.changes(of: .sleep, added: added, deleted: result.deletedObjects, newAnchor: result.newAnchor,
                                isFullRead: anchor == nil)
    }

    private static func changes(of kind: HealthSampleKind, added: [CachedHealthSample], deleted: [HKDeletedObject],
                                newAnchor: HKQueryAnchor, isFullRead: Bool) throws -> HealthSampleChanges {
        HealthSampleChanges(
            kind: kind, added: added, deletedHealthKitUUIDs: deleted.map { $0.uuid.uuidString },
            anchor: try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true), isFullRead: isFullRead)
    }

    // MARK: - Entraînements

    /// Les courses et les vélos commencés après `start` (spec M6 §3). La distance est celle de la discipline, la fréquence
    /// cardiaque moyenne celle qu'Apple Santé a associée à l'entraînement : une montre tierce peut n'en fournir aucune.
    public func workoutChanges(of signal: WorkoutSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        let queryAnchor = anchor.flatMap(Self.decodedAnchor)
        let activity: HKWorkoutActivityType = signal == .run ? .running : .cycling
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: activity),
            HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        ])
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout(predicate)], anchor: queryAnchor)
        let result = try await descriptor.result(for: store)
        let distanceType = HKQuantityType(signal == .run ? .distanceWalkingRunning : .distanceCycling)
        let added = result.addedSamples.map { workout in
            CachedHealthSample(
                kind: signal.kind, start: workout.startDate, end: workout.endDate,
                distanceMeters: workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()),
                averageHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?
                    .doubleValue(for: Self.beatsPerMinute),
                durationMinutes: workout.duration / 60, healthKitUUID: workout.uuid.uuidString,
                sourceBundleID: workout.sourceRevision.source.bundleIdentifier, fetchedAt: workout.endDate)
        }
        return try Self.changes(of: signal.kind, added: added, deleted: result.deletedObjects, newAnchor: result.newAnchor,
                                isFullRead: queryAnchor == nil)
    }

    /// Les entraînements autres que course et vélo commencés après `start`, de toutes les apps, Pulse compris : c'est à la lecture
    /// du cache que les siens sont écartés. La famille va dans `value`.
    public func otherWorkoutChanges(since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        let queryAnchor = anchor.flatMap(Self.decodedAnchor)
        let sessions = HealthKitWorkoutFamily.sessionTypes.map { HKQuery.predicateForWorkouts(with: $0) }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSCompoundPredicate(notPredicateWithSubpredicate: NSCompoundPredicate(orPredicateWithSubpredicates: sessions)),
            HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        ])
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.workout(predicate)], anchor: queryAnchor)
        let result = try await descriptor.result(for: store)
        let added = result.addedSamples.map { workout in
            CachedHealthSample(
                kind: .otherWorkout, start: workout.startDate, end: workout.endDate,
                value: Double(HealthKitWorkoutFamily.family(of: workout.workoutActivityType).rawValue),
                averageHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?
                    .doubleValue(for: Self.beatsPerMinute),
                durationMinutes: workout.duration / 60, healthKitUUID: workout.uuid.uuidString,
                sourceBundleID: workout.sourceRevision.source.bundleIdentifier, fetchedAt: workout.endDate)
        }
        return try Self.changes(of: .otherWorkout, added: added, deleted: result.deletedObjects, newAnchor: result.newAnchor,
                                isFullRead: queryAnchor == nil)
    }

    // MARK: - Poids et masse grasse

    /// Le poids en kilos et la masse grasse en pourcentage 0…100 (HealthKit la rend en fraction), par la même requête ancrée que
    /// les nuits (spec M7 §14).
    public func bodyChanges(of signal: BodySignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        let dates = HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        switch signal {
        case .bodyMass:
            return try await quantityChanges(of: signal.kind, .bodyMass, unit: .gramUnit(with: .kilo),
                                             anchor: anchor.flatMap(Self.decodedAnchor), dates: dates)
        case .bodyFat:
            return try await quantityChanges(of: signal.kind, .bodyFatPercentage, unit: .percent(), scale: 100,
                                             anchor: anchor.flatMap(Self.decodedAnchor), dates: dates)
        }
    }

    /// Une ancre illisible vaut une ancre absente : la lecture repart de zéro.
    private static func decodedAnchor(_ data: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}
