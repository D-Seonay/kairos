import Foundation

/// Les types Apple Santé que Pulse lit en V1 (spec §7).
public enum HealthDataType: String, CaseIterable, Sendable, Identifiable {
    case sleepAnalysis
    case hrvSDNN
    case restingHeartRate
    case heartRate
    case runningWorkouts
    case bodyMass

    public var id: String { rawValue }

    /// Titre affiché, en français.
    public var title: String {
        switch self {
        case .sleepAnalysis: String(localized: "Sommeil", bundle: .module)
        case .hrvSDNN: String(localized: "VFC (SDNN)", bundle: .module)
        case .restingHeartRate: String(localized: "FC au repos", bundle: .module)
        case .heartRate: String(localized: "Fréquence cardiaque", bundle: .module)
        case .runningWorkouts: String(localized: "Courses", bundle: .module)
        case .bodyMass: String(localized: "Poids", bundle: .module)
        }
    }
}

/// Le dernier échantillon reçu pour un type, avec sa source : ce que l'écran de diagnostic affiche.
public struct HealthSamplePoint: Sendable, Equatable {
    public let type: HealthDataType
    public let date: Date
    /// Valeur formatée avec son unité (« 52 ms », « 49 bpm », « 7 h 30 », « 5,2 km », « 78,4 kg »).
    public let valueText: String
    public let sourceName: String
    public let sourceBundleID: String

    public init(type: HealthDataType, date: Date, valueText: String, sourceName: String, sourceBundleID: String) {
        self.type = type
        self.date = date
        self.valueText = valueText
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
    }
}
