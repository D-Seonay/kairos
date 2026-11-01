import Foundation
import HealthKit
import PulseDomain

/// Lecture réelle d'Apple Santé. `HKHealthStore` est thread-safe, d'où `@unchecked Sendable`.
public final class HealthKitReader: HealthReading, @unchecked Sendable {
    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    // MARK: - HealthReading

    public func requestReadAuthorization() async throws {
        let types: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKQuantityType(.bodyMass),
            HKWorkoutType.workoutType()
        ]
        try await store.requestAuthorization(toShare: [], read: types)
    }

    public func latestSample(of type: HealthDataType) async throws -> HealthSamplePoint? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [Self.predicate(for: type, in: nil)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try await descriptor.result(for: store).first else { return nil }
        return HealthSamplePoint(
            type: type,
            date: sample.endDate,
            valueText: Self.valueText(for: sample, type: type),
            sourceName: sample.sourceRevision.source.name,
            sourceBundleID: sample.sourceRevision.source.bundleIdentifier
        )
    }

    /// Plafond du comptage : au-delà, l'écran affiche « 10 000 » et la requête ne charge pas des années d'échantillons.
    public static let sampleCountLimit = 10_000

    public func sampleCount(of type: HealthDataType, from: Date, to: Date) async throws -> Int {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [Self.predicate(for: type, in: DateInterval(start: from, end: to))],
            sortDescriptors: [],
            limit: Self.sampleCountLimit
        )
        return try await descriptor.result(for: store).count
    }

    public func sdnnSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try await quantitySamples(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: from, to: to)
    }

    public func restingHeartRateSamples(from: Date, to: Date) async throws -> [TimedSample] {
        try await quantitySamples(.restingHeartRate, unit: Self.beatsPerMinute, from: from, to: to)
    }

    public func sleepIntervals(from: Date, to: Date) async throws -> [SleepInterval] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: Self.datePredicate(from: from, to: to))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return try await descriptor.result(for: store).compactMap { sample in
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value), let stage = Self.stage(for: value) else { return nil }
            return SleepInterval(start: sample.startDate, end: sample.endDate, stage: stage)
        }
    }

    // MARK: - Requêtes

    private func quantitySamples(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date) async throws -> [TimedSample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: Self.datePredicate(from: from, to: to))],
            sortDescriptors: [SortDescriptor(\.endDate)]
        )
        return try await descriptor.result(for: store).map {
            TimedSample(date: $0.endDate, value: $0.quantity.doubleValue(for: unit))
        }
    }

    private static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())

    private static func datePredicate(from: Date, to: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: from, end: to, options: [])
    }

    private static func predicate(for type: HealthDataType, in interval: DateInterval?) -> HKSamplePredicate<HKSample> {
        let dates = interval.map { datePredicate(from: $0.start, to: $0.end) }
        switch type {
        case .sleepAnalysis:
            return .sample(type: HKCategoryType(.sleepAnalysis), predicate: dates)
        case .hrvSDNN:
            return .sample(type: HKQuantityType(.heartRateVariabilitySDNN), predicate: dates)
        case .restingHeartRate:
            return .sample(type: HKQuantityType(.restingHeartRate), predicate: dates)
        case .heartRate:
            return .sample(type: HKQuantityType(.heartRate), predicate: dates)
        case .bodyMass:
            return .sample(type: HKQuantityType(.bodyMass), predicate: dates)
        case .runningWorkouts:
            let running = HKQuery.predicateForWorkouts(with: .running)
            let combined = dates.map { NSCompoundPredicate(andPredicateWithSubpredicates: [running, $0]) } ?? running
            return .sample(type: HKWorkoutType.workoutType(), predicate: combined)
        }
    }

    // MARK: - Conversions

    private static func stage(for value: HKCategoryValueSleepAnalysis) -> SleepStage? {
        switch value {
        case .inBed: .inBed
        case .awake: .awake
        case .asleepUnspecified: .asleepUnspecified
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepREM: .rem
        @unknown default: nil
        }
    }

    static func valueText(for sample: HKSample, type: HealthDataType) -> String {
        switch type {
        case .hrvSDNN:
            guard let quantity = (sample as? HKQuantitySample)?.quantity else { return "" }
            return "\(quantity.doubleValue(for: .secondUnit(with: .milli)).formatted(.number.precision(.fractionLength(0)))) ms"
        case .restingHeartRate, .heartRate:
            guard let quantity = (sample as? HKQuantitySample)?.quantity else { return "" }
            return "\(quantity.doubleValue(for: beatsPerMinute).formatted(.number.precision(.fractionLength(0)))) bpm"
        case .bodyMass:
            guard let quantity = (sample as? HKQuantitySample)?.quantity else { return "" }
            return "\(quantity.doubleValue(for: .gramUnit(with: .kilo)).formatted(.number.precision(.fractionLength(1)))) kg"
        case .sleepAnalysis:
            let stageName = (sample as? HKCategorySample)
                .flatMap { HKCategoryValueSleepAnalysis(rawValue: $0.value) }
                .flatMap(stage(for:))
                .map(\.localizedName) ?? ""
            return "\(durationText(sample.endDate.timeIntervalSince(sample.startDate))) \(stageName)".trimmingCharacters(in: .whitespaces)
        case .runningWorkouts:
            guard let workout = sample as? HKWorkout else { return "" }
            if let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter()) {
                return "\((meters / 1000).formatted(.number.precision(.fractionLength(1)))) km"
            }
            return durationText(workout.duration)
        }
    }

    /// « 7 h 30 », « 45 min ».
    private static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(String(format: "%02d", minutes % 60))" : "\(minutes) min"
    }
}
