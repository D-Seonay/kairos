import Foundation
import HealthKit
import PulseDomain

/// La lecture Apple Santé vue par le moteur et les fonctionnalités. Aucune valeur lue n'est journalisée.
extension HealthKitReader: HealthSampleSource {
    public func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: HealthKitTypes.read)
    }

    /// Une requête ancrée par signal. Une ancre absente ou illisible donne une lecture complète des échantillons postérieurs à `start`.
    public func changes(of signal: NightSignal, since anchor: Data?, from start: Date) async throws -> HealthSampleChanges {
        let queryAnchor = anchor.flatMap(Self.decodedAnchor)
        let dates = HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        switch signal {
        case .sdnn:
            return try await quantityChanges(of: signal, .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli),
                                             anchor: queryAnchor, dates: dates)
        case .restingHeartRate:
            return try await quantityChanges(of: signal, .restingHeartRate, unit: Self.beatsPerMinute, anchor: queryAnchor, dates: dates)
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
    private func quantityChanges(of signal: NightSignal, _ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                                 anchor: HKQueryAnchor?, dates: NSPredicate) async throws -> HealthSampleChanges {
        let descriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: dates)], anchor: anchor)
        let result = try await descriptor.result(for: store)
        let added = result.addedSamples.map { sample in
            CachedHealthSample(
                kind: signal.kind, start: sample.endDate, end: sample.endDate, value: sample.quantity.doubleValue(for: unit),
                healthKitUUID: sample.uuid.uuidString, sourceBundleID: sample.sourceRevision.source.bundleIdentifier,
                fetchedAt: sample.endDate)
        }
        return try Self.changes(of: signal, added: added, deleted: result.deletedObjects, newAnchor: result.newAnchor,
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

    private static func changes(of signal: NightSignal, added: [CachedHealthSample], deleted: [HKDeletedObject], newAnchor: HKQueryAnchor,
                                isFullRead: Bool) throws -> HealthSampleChanges {
        HealthSampleChanges(
            kind: signal.kind, added: added, deletedHealthKitUUIDs: deleted.map { $0.uuid.uuidString },
            anchor: try NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true), isFullRead: isFullRead)
    }

    /// Une ancre illisible vaut une ancre absente : la lecture repart de zéro.
    private static func decodedAnchor(_ data: Data) -> HKQueryAnchor? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}
