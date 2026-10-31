import Foundation

/// Une valeur numérique datée, telle que lue dans Apple Santé (SDNN en ms, FC repos en bpm).
public struct TimedSample: Sendable, Equatable, Codable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
