import Foundation

/// La pose d'une photo de corps ; l'ordre des cas est l'ordre d'affichage : face, profil, dos.
public enum BodyPose: String, Sendable, Codable, CaseIterable {
    case front
    case side
    case back
}

/// Une photo de corps. Elle n'a ni modèle SwiftData ni copie iCloud : seul son fichier, sur l'iPhone, la garde.
public struct BodyPhoto: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var pose: BodyPose
    /// La date choisie : celle des métadonnées de l'image, sinon aujourd'hui, modifiable.
    public var takenAt: Date
    public var createdAt: Date

    public init(id: UUID, pose: BodyPose, takenAt: Date, createdAt: Date) {
        self.id = id
        self.pose = pose
        self.takenAt = takenAt
        self.createdAt = createdAt
    }
}
