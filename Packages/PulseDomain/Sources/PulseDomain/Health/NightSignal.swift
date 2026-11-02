import Foundation

/// Les trois signaux de la nuit, dans l'ordre de lecture d'Apple Santé.
public enum NightSignal: String, Sendable, CaseIterable {
    case sdnn
    case restingHeartRate
    case sleep

    public var kind: HealthSampleKind {
        switch self {
        case .sdnn: .sdnn
        case .restingHeartRate: .restingHeartRate
        case .sleep: .sleep
        }
    }
}
