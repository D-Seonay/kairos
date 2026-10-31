/// Un facteur physiologique qui entre dans le score de récupération.
public enum Factor: String, Sendable, Codable, CaseIterable {
    case hrv
    case restingHeartRate
    case sleep
}
