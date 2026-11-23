import Foundation
import PulseDomain

/// Allège un tracé GPS avant de le garder : une heure de course à 1 point par seconde tient en quelques centaines de points.
public enum RouteSimplifier {
    private static let metersPerDegree = 111_320.0

    /// Douglas-Peucker en mètres (projection locale équirectangulaire). Garde toujours le premier et le dernier point.
    public static func simplify(_ points: [RunTrackPoint], toleranceMeters: Double = 5) -> [RunTrackPoint] {
        guard points.count > 2 else { return points }
        let projected = project(points)
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        // Pile explicite plutôt que récursion : une course de plusieurs heures reste sans risque de pile.
        var pending = [(first: Int, last: Int)(0, points.count - 1)]
        while let range = pending.popLast() {
            guard range.last - range.first > 1 else { continue }
            var farthest = range.first
            var farthestDistance = 0.0
            for index in (range.first + 1)..<range.last {
                let distance = distance(from: projected[index], toSegment: projected[range.first], projected[range.last])
                if distance > farthestDistance {
                    farthestDistance = distance
                    farthest = index
                }
            }
            guard farthestDistance > toleranceMeters else { continue }
            keep[farthest] = true
            pending.append((range.first, farthest))
            pending.append((farthest, range.last))
        }
        return points.indices.filter { keep[$0] }.map { points[$0] }
    }

    /// Coordonnées locales en mètres (x vers l'est, y vers le nord), autour du premier point.
    private static func project(_ points: [RunTrackPoint]) -> [(x: Double, y: Double)] {
        let origin = points[0]
        let scale = metersPerDegree * cos(origin.latitude * .pi / 180)
        return points.map { (($0.longitude - origin.longitude) * scale, ($0.latitude - origin.latitude) * metersPerDegree) }
    }

    /// Distance d'un point à un segment, en mètres ; un segment réduit à un point (tracé en boucle) se mesure à ce point.
    private static func distance(from point: (x: Double, y: Double), toSegment origin: (x: Double, y: Double),
                                 _ end: (x: Double, y: Double)) -> Double {
        let dx = end.x - origin.x
        let dy = end.y - origin.y
        let lengthSquared = dx * dx + dy * dy
        let ratio = lengthSquared == 0 ? 0 : max(0, min(1, ((point.x - origin.x) * dx + (point.y - origin.y) * dy) / lengthSquared))
        return hypot(point.x - (origin.x + ratio * dx), point.y - (origin.y + ratio * dy))
    }
}
