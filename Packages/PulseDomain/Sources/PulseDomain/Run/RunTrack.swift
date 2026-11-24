import Foundation

/// Un point GPS d'une course, tel que livré par le système.
public struct RunTrackPoint: Sendable, Equatable, Codable {
    public var timestamp: Date
    public var latitude: Double
    public var longitude: Double
    /// En mètres ; `nil` si le système n'en donne pas.
    public var altitude: Double?
    /// Rayon d'incertitude de la position, en mètres.
    public var horizontalAccuracy: Double
    public var verticalAccuracy: Double?

    public init(timestamp: Date, latitude: Double, longitude: Double, altitude: Double? = nil,
                horizontalAccuracy: Double, verticalAccuracy: Double? = nil) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
    }
}

/// Une pause de la course : le temps écoulé entre `start` et `end` ne compte pas en mouvement.
public struct RunPause: Sendable, Equatable, Codable {
    public var start: Date
    /// `nil` tant que la pause est en cours.
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }
}

/// Le temps d'un kilomètre ; le dernier, partiel, couvre moins de 1 000 m.
public struct RunSplit: Sendable, Equatable, Codable {
    /// Rang du kilomètre, à partir de 1.
    public var kilometer: Int
    public var seconds: Double
    public var distanceMeters: Double

    public init(kilometer: Int, seconds: Double, distanceMeters: Double) {
        self.kilometer = kilometer
        self.seconds = seconds
        self.distanceMeters = distanceMeters
    }
}

/// Le tracé d'une course terminée, rattaché à sa séance (`id` est l'identifiant de la séance).
public struct RunTrack: Sendable, Equatable, Codable, Identifiable {
    public var id: UUID
    /// Points simplifiés (environ 5 m) ; les points bruts ne sont pas gardés.
    public var points: [RunTrackPoint]
    public var splits: [RunSplit]
    public var elevationGainMeters: Double?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, points: [RunTrackPoint], splits: [RunSplit], elevationGainMeters: Double? = nil,
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.points = points
        self.splits = splits
        self.elevationGainMeters = elevationGainMeters
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
