import PulseDomain

/// Le jour du programme après application du tableau de la catégorie, avec les ajustements nommés (spec V1 §6.5).
public struct AdjustedSession: Sendable, Equatable {
    public var day: RoutineDay
    public var adjustments: [SessionAdjustment]
    public var removedSets: Int

    public var isVolumeReduced: Bool { removedSets > 0 }
    public var isReplacedByMobility: Bool { adjustments.contains { $0.kind == .replaceWithMobility } }

    public init(day: RoutineDay, adjustments: [SessionAdjustment] = [], removedSets: Int = 0) {
        self.day = day
        self.adjustments = adjustments
        self.removedSets = removedSets
    }
}
