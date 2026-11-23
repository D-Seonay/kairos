import Foundation

/// La silhouette de la carte musculaire, tirée du sexe du profil. « Autre » donne la silhouette de femme, celle que l'app
/// montrait avant ce choix.
public enum MuscleMapFigure: String, Sendable, Codable, CaseIterable {
    case female
    case male

    public init(sex: Sex) {
        switch sex {
        case .male: self = .male
        case .female, .unspecified: self = .female
        }
    }
}
