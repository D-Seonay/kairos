import Foundation

/// Phase de sommeil telle qu'exposée par Apple Santé.
public enum SleepStage: String, Sendable, Codable {
    case inBed
    case awake
    case asleepUnspecified
    case core
    case deep
    case rem

    /// Vrai pour les phases pendant lesquelles l'utilisateur dort.
    public var isAsleep: Bool {
        switch self {
        case .asleepUnspecified, .core, .deep, .rem: true
        case .inBed, .awake: false
        }
    }
}

/// Un intervalle de sommeil d'une seule phase.
public struct SleepInterval: Sendable, Equatable, Codable {
    public var start: Date
    public var end: Date
    public var stage: SleepStage

    public init(start: Date, end: Date, stage: SleepStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }
}
