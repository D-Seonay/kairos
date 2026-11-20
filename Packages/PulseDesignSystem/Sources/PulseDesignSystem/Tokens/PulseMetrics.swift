import CoreGraphics

/// Rayons et espacements. Le rayon dit la hiérarchie : la dalle du score est la plus ronde, les cartes ensuite, les contrôles
/// sont des capsules.
public enum PulseMetrics {
    /// La dalle tramée (`OpalCard`), la pièce maîtresse d'un écran.
    public static let radiusHero: CGFloat = 34
    public static let radius: CGFloat = 26
    public static let radiusSmall: CGFloat = 16
    public static let radiusTiny: CGFloat = 12
    public static let minButtonHeight: CGFloat = 56
    public static let spacing: CGFloat = 16
}
