import Foundation
import HealthKit
import PulseDomain

/// La lecture Apple Santé vue par le moteur et les fonctionnalités. Aucune valeur lue n'est journalisée.
extension HealthKitReader: HealthSampleSource {
    /// Tout ce que Pulse lit : nuits, VFC, fréquences cardiaques, entraînements, mensurations et caractéristiques du profil.
    public func requestAuthorization() async throws {
        let types: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKWorkoutType.workoutType(),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.height),
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex)
        ]
        try await store.requestAuthorization(toShare: [], read: types)
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
}
