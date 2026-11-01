import CoreGraphics
import SwiftUI

/// La géométrie du cadran : un arc de 240° ouvert vers le bas, de 8 h (bas gauche) à 4 h (bas droite) en passant par le haut.
/// Angles SwiftUI : 0° à 3 h, sens horaire.
public enum GaugeGeometry {
    public static let startDegrees = 150.0
    public static let sweepDegrees = 240.0

    /// Les seuils de catégorie (40 / 65 / 90) en fraction de l'arc.
    public static let thresholdFractions: [Double] = [0.40, 0.65, 0.90]

    /// L'angle du score, borné à 0…100. Un score non fini compte pour 0.
    public static func angle(for score: Double) -> Angle {
        .degrees(startDegrees + sweepDegrees * fraction(for: score))
    }

    /// Le point du repère sur l'arc tracé avec `lineWidth` dans `rect` : le cercle inscrit, au rayon de la ligne médiane.
    public static func point(for score: Double, in rect: CGRect, lineWidth: CGFloat) -> CGPoint {
        let radius = max(0, min(rect.width, rect.height) / 2 - lineWidth / 2)
        let radians = angle(for: score).radians
        return CGPoint(x: rect.midX + radius * cos(radians), y: rect.midY + radius * sin(radians))
    }

    /// La part de l'arc couverte par le score, entre 0 et 1.
    static func fraction(for score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return min(max(score, 0), 100) / 100
    }
}
