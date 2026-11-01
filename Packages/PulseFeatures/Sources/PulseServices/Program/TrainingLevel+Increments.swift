import PulseDomain

extension TrainingLevel {
    /// Incréments de charge par défaut, en kg, pour le haut et le bas du corps.
    public var defaultIncrementsKg: (upper: Double, lower: Double) {
        switch self {
        case .beginner, .intermediate: (upper: 2.5, lower: 5)
        case .advanced: (upper: 1.25, lower: 2.5)
        }
    }
}
