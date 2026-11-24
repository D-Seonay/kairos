import ActivityKit
import Foundation

/// La Live Activity de la course en cours. Elle ne porte que le titre, le temps, la distance GPS filtrée et l'allure moyenne :
/// aucune donnée de santé (frontière M8), jamais de fréquence cardiaque.
public struct PulseRunAttributes: ActivityAttributes, Sendable {
    /// Ce qui change pendant la course : les champs de `RunActivityState`, sauf l'identifiant, porté par les attributs. Le temps en
    /// mouvement part de `timerStart` (minuteur système) ; en pause, `frozenElapsedSeconds` est affiché figé.
    public struct ContentState: Codable, Hashable, Sendable {
        public var title: String
        /// Début du chronomètre en mouvement ; `nil` en pause.
        public var timerStart: Date?
        public var frozenElapsedSeconds: Int
        public var distanceMeters: Double?
        public var averagePaceSecondsPerKm: Int?
        public var isPaused: Bool

        public init(title: String, timerStart: Date? = nil, frozenElapsedSeconds: Int = 0, distanceMeters: Double? = nil,
                    averagePaceSecondsPerKm: Int? = nil, isPaused: Bool = false) {
            self.title = title
            self.timerStart = timerStart
            self.frozenElapsedSeconds = frozenElapsedSeconds
            self.distanceMeters = distanceMeters
            self.averagePaceSecondsPerKm = averagePaceSecondsPerKm
            self.isPaused = isPaused
        }
    }

    /// La course de l'activité : au lancement, l'app ferme celles qui ne correspondent plus à la course en cours.
    public var sessionID: UUID

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }
}
