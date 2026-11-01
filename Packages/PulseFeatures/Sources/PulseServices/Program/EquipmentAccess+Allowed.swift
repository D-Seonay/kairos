import PulseDomain

extension EquipmentAccess {
    /// Le matériel que l'utilisateur déclare avoir sous la main.
    public var allowedEquipment: Set<Equipment> {
        switch self {
        case .fullGym: Set(Equipment.allCases)
        case .homeGym: [.dumbbell, .kettlebell, .band, .bodyweight]
        case .bodyweight: [.bodyweight]
        }
    }
}
