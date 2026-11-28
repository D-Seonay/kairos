import Foundation

/// Les signaux de la nuit, dans l'ordre de lecture d'Apple Santé. La fréquence cardiaque brute ne sert qu'à la FC la plus basse
/// du sommeil : elle n'est lue que sur `heartRateHistoryDays` jours et ne réveille jamais l'app en arrière-plan.
public enum NightSignal: String, Sendable, CaseIterable {
    case sdnn
    case restingHeartRate
    case sleep
    case heartRate

    /// Les jours de fréquence cardiaque brute lus et gardés : la nuit du jour, les 7 de la référence de FC de repos, et de la marge.
    public static let heartRateHistoryDays = 10

    /// Les signaux dont un nouvel échantillon doit déclencher une lecture en arrière-plan : tous sauf la fréquence cardiaque
    /// brute, écrite plusieurs fois par heure.
    public static var observed: [NightSignal] {
        allCases.filter { $0 != .heartRate }
    }

    public var kind: HealthSampleKind {
        switch self {
        case .sdnn: .sdnn
        case .restingHeartRate: .restingHeartRate
        case .heartRate: .heartRate
        case .sleep: .sleep
        }
    }
}
