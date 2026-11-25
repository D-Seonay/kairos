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
    /// Vrai si HealthKit a gardé l'entraînement pour l'écrire au déverrouillage : il n'est jamais écrit une seconde fois.
    /// Faux pour les brouillons plus anciens.
    public var healthWriteDeferred: Bool
    public var updatedAt: Date

    public init(sessionID: UUID, launch: RunLaunch, startedAt: Date, pauses: [RunPause] = [],
                points: [RunTrackPoint] = [], heartRates: [Double] = [], locationDenied: Bool = false,
                healthKitUUID: UUID? = nil, healthWriteDeferred: Bool = false, updatedAt: Date) {
        self.sessionID = sessionID
        self.launch = launch
        self.startedAt = startedAt
        self.pauses = pauses
        self.points = points
        self.heartRates = heartRates
        self.locationDenied = locationDenied
        self.healthKitUUID = healthKitUUID
        self.healthWriteDeferred = healthWriteDeferred
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID, launch, startedAt, pauses, points, heartRates, locationDenied, healthKitUUID, healthWriteDeferred, updatedAt
    }

    /// Un brouillon écrit avant l'ajout de `healthWriteDeferred` se relit sans lui.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        launch = try container.decode(RunLaunch.self, forKey: .launch)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        pauses = try container.decode([RunPause].self, forKey: .pauses)
        points = try container.decode([RunTrackPoint].self, forKey: .points)
        heartRates = try container.decode([Double].self, forKey: .heartRates)
        locationDenied = try container.decode(Bool.self, forKey: .locationDenied)
        healthKitUUID = try container.decodeIfPresent(UUID.self, forKey: .healthKitUUID)
        healthWriteDeferred = try container.decodeIfPresent(Bool.self, forKey: .healthWriteDeferred) ?? false
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
