import Foundation

/// Ce qui démarre une course : le titre et, pour une séance planifiée, son objectif et son origine.
public struct RunLaunch: Sendable, Equatable, Codable {
    public var title: String
    public var programID: UUID?
    public var routineDayID: UUID?
    public var runType: RunType?
    public var targetMinutes: Int?
    public var targetKm: Double?
    /// Ajustement du moteur à rappeler pendant la course, en français.
    public var adjustmentNote: String?

    public init(title: String, programID: UUID? = nil, routineDayID: UUID? = nil, runType: RunType? = nil,
                targetMinutes: Int? = nil, targetKm: Double? = nil, adjustmentNote: String? = nil) {
        self.title = title
        self.programID = programID
        self.routineDayID = routineDayID
        self.runType = runType
        self.targetMinutes = targetMinutes
        self.targetKm = targetKm
        self.adjustmentNote = adjustmentNote
    }

    /// Progression 0…1 vers l'objectif ; `nil` sans objectif, ou sans distance quand l'objectif en est une.
    /// Non bornée au-dessus de 1, pour que l'annonce « objectif atteint » se déclenche à 1 ou plus.
    public func targetProgress(movingSeconds: Double, distanceMeters: Double?) -> Double? {
        if let targetMinutes, targetMinutes > 0 {
            return movingSeconds / (Double(targetMinutes) * 60)
        }
        if let targetKm, targetKm > 0, let distanceMeters {
            return distanceMeters / (targetKm * 1_000)
        }
        return nil
    }
}
