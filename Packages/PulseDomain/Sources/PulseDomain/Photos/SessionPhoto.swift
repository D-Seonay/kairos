import Foundation

/// Les métadonnées d'une photo de séance ; l'image vit à part (`PhotoImage`).
public struct SessionPhoto: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var sessionID: UUID
    /// Rang d'affichage dans la séance, à partir de 0.
    public var order: Int
    public var createdAt: Date
    public var updatedAt: Date

    /// Nombre de photos au plus par séance.
    public static let maxPerSession = 6

    public init(id: UUID, sessionID: UUID, order: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.sessionID = sessionID
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Une image et sa vignette, toutes deux en JPEG.
public struct PhotoImage: Sendable, Equatable {
    /// Grand côté de 2 048 px, environ 600 Ko.
    public var image: Data
    /// Grand côté de 400 px.
    public var thumbnail: Data

    public init(image: Data, thumbnail: Data) {
        self.image = image
        self.thumbnail = thumbnail
    }
}
