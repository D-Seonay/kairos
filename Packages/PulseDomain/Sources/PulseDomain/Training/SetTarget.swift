/// Fourchette de répétitions visée pour une série précise d'un exercice de routine.
public struct SetTarget: Sendable, Equatable, Codable {
    public var repsMin: Int
    public var repsMax: Int

    public init(repsMin: Int, repsMax: Int) {
        self.repsMin = repsMin
        self.repsMax = repsMax
    }
}
