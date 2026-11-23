import Foundation

/// L'état d'une course en cours, écrit régulièrement pour la reprendre après une interruption.
public struct RunDraft: Sendable, Equatable, Codable {
    public var sessionID: UUID
    public var launch: RunLaunch
    public var startedAt: Date
    public var pauses: [RunPause]
    /// Points bruts, avant filtrage et simplification.
    public var points: [RunTrackPoint]
    /// Fréquences cardiaques livrées par la séance HealthKit ; elles restent locales (frontière M8).
    public var heartRates: [Double]
    /// Vrai si la localisation a été refusée : la course continue sans tracé.
    public var locationDenied: Bool
    /// L'entraînement déjà écrit dans Santé par une fin dont l'enregistrement a échoué : la reprise le réutilise au lieu d'en
    /// écrire un second. Absent des brouillons plus anciens.
    public var healthKitUUID: UUID?
    public var updatedAt: Date

    public init(sessionID: UUID, launch: RunLaunch, startedAt: Date, pauses: [RunPause] = [],
                points: [RunTrackPoint] = [], heartRates: [Double] = [], locationDenied: Bool = false,
                healthKitUUID: UUID? = nil, updatedAt: Date) {
        self.sessionID = sessionID
        self.launch = launch
        self.startedAt = startedAt
        self.pauses = pauses
        self.points = points
        self.heartRates = heartRates
        self.locationDenied = locationDenied
        self.healthKitUUID = healthKitUUID
        self.updatedAt = updatedAt
    }
}
