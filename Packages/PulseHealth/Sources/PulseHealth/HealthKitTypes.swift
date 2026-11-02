import HealthKit
import PulseDomain

/// La liste unique des types Apple Santé que Pulse lit, et la correspondance avec les signaux de la nuit.
public enum HealthKitTypes {
    /// Tout ce que Pulse lit : nuits, VFC, fréquences cardiaques, entraînements, mensurations et caractéristiques du profil.
    public static var read: Set<HKObjectType> {
        [
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
    }

    public static func sampleType(for signal: NightSignal) -> HKSampleType {
        switch signal {
        case .sdnn: HKQuantityType(.heartRateVariabilitySDNN)
        case .restingHeartRate: HKQuantityType(.restingHeartRate)
        case .sleep: HKCategoryType(.sleepAnalysis)
        }
    }

    /// Les types dont un nouvel échantillon doit déclencher une lecture : les trois signaux de la nuit.
    public static var observed: [HKSampleType] {
        NightSignal.allCases.map(sampleType(for:))
    }
}
