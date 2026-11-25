import Foundation

/// Un instant d'une course : le temps écoulé depuis le départ et la distance cumulée à cet instant.
public struct RunSegmentSample: Sendable, Equatable {
    /// En secondes depuis le départ (en mouvement quand les pauses sont connues).
    public var seconds: Double
    /// Distance cumulée, en mètres ; ne décroît jamais.
    public var meters: Double

    public init(seconds: Double, meters: Double) {
        self.seconds = seconds
        self.meters = meters
    }
}

/// Le meilleur segment continu d'une course : la fenêtre glissante la plus rapide sur une distance donnée (5 km dans une sortie
/// de 12 km, par exemple). Pur calcul, sur une suite d'instants (temps, distance cumulée).
public enum RunSegments {
    /// Le temps le plus court, en secondes, pour couvrir `distance` mètres d'un seul tenant ; `nil` si la course est plus courte.
    ///
    /// Entre deux instants, la distance avance à vitesse constante : un bord de fenêtre qui tombe entre deux instants est
    /// interpolé. Avec une distance linéaire par morceaux, la fenêtre la plus rapide a toujours un bord sur un instant : on essaie
    /// donc chaque instant comme début, puis comme fin, en deux passes linéaires. Les instants doivent être rangés par temps.
    public static func fastest(meters distance: Double, in samples: [RunSegmentSample]) -> Double? {
        guard distance > 0, let first = samples.first, let last = samples.last,
              last.meters - first.meters >= distance else { return nil }
        var best = Double.infinity

        // Fenêtres qui commencent sur un instant : la fin est le premier moment où la distance atteint la cible.
        var end = 0
        for start in samples.indices {
            let target = samples[start].meters + distance
            guard target <= last.meters else { break }
            end = max(end, start)
            while samples[end].meters < target { end += 1 }
            let reached = time(at: target, from: samples[end - 1], to: samples[end])
            best = min(best, reached - samples[start].seconds)
        }

        // Fenêtres qui finissent sur un instant : le début est le dernier moment où la distance valait encore la cible.
        var start = 0
        for end in samples.indices {
            let target = samples[end].meters - distance
            guard target >= first.meters else { continue }
            while start + 1 < end, samples[start + 1].meters <= target { start += 1 }
            let left = time(at: target, from: samples[start], to: samples[start + 1])
            best = min(best, samples[end].seconds - left)
        }
        return best.isFinite ? best : nil
    }

    /// L'instant où la distance vaut `meters`, entre deux instants qui l'encadrent (`lower.meters <= meters <= upper.meters`).
    private static func time(at meters: Double, from lower: RunSegmentSample, to upper: RunSegmentSample) -> Double {
        let span = upper.meters - lower.meters
        guard span > 0 else { return upper.seconds }
        return lower.seconds + (meters - lower.meters) / span * (upper.seconds - lower.seconds)
    }

    /// Les instants d'un tracé enregistré : le temps depuis le premier point et la distance cumulée (haversine) point à point.
    /// `totalMeters`, s'il est connu, recale la distance sur celle de la séance : le tracé simplifié est un peu plus court que la
    /// distance filtrée mesurée pendant la course.
    public static func samples(from points: [RunTrackPoint], totalMeters: Double? = nil) -> [RunSegmentSample] {
        guard let origin = points.first?.timestamp else { return [] }
        var cumulative = 0.0
        var raw: [RunSegmentSample] = []
        raw.reserveCapacity(points.count)
        for (index, point) in points.enumerated() {
            if index > 0 { cumulative += meters(from: points[index - 1], to: point) }
            raw.append(RunSegmentSample(seconds: point.timestamp.timeIntervalSince(origin), meters: cumulative))
        }
        guard let total = totalMeters, total > 0, cumulative > 0 else { return raw }
        let scale = total / cumulative
        var scaled = raw.map { RunSegmentSample(seconds: $0.seconds, meters: $0.meters * scale) }
        // Le dernier instant vaut exactement la distance de la séance : un arrondi ne fait pas manquer un 5 km tout juste couvert.
        scaled[scaled.count - 1].meters = total
        return scaled
    }

    private static let earthRadius = 6_371_000.0

    /// Distance haversine entre deux points, en mètres.
    static func meters(from origin: RunTrackPoint, to target: RunTrackPoint) -> Double {
        let latA = origin.latitude * .pi / 180
        let latB = target.latitude * .pi / 180
        let deltaLat = latB - latA
        let deltaLon = (target.longitude - origin.longitude) * .pi / 180
        let haversine = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(latA) * cos(latB) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(haversine)))
    }
}
