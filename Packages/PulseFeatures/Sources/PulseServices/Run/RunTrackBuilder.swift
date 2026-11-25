import Foundation
import PulseDomain

/// Construit une course point par point : distance GPS filtrée, passages aux kilomètres, allures et dénivelé.
/// Pur calcul, sans horloge ni capteur : le service de course lui passe les points et les pauses.
public struct RunTrackBuilder: Sendable, Equatable {
    /// Au-delà, le point est ignoré (m).
    public static let maxHorizontalAccuracy = 25.0
    /// Au-delà, le point est ignoré : 25 km/h (m/s).
    public static let maxSpeed = 25.0 / 3.6
    /// Précision à partir de laquelle le GPS est « Prêt » (m).
    public static let readyAccuracy = 20.0

    /// Sous ce pas depuis le dernier point retenu, le point est du bruit à l'arrêt : il est ignoré (m).
    public static let minimumStep = 5.0

    private static let earthRadius = 6_371_000.0
    private static let kilometer = 1_000.0
    private static let shortKilometer = 100.0
    /// Sous ce reste après le dernier km, on n'ajoute pas de km partiel (sauf dans le premier km) : ce serait du bruit GPS.
    private static let minPartialMeters = 10.0
    private static let paceWindow = 30.0
    private static let minWindowMeters = 20.0
    private static let minAveragePaceMeters = 50.0
    private static let maxVerticalAccuracy = 10.0
    private static let elevationHysteresis = 3.0

    public let startedAt: Date
    public private(set) var distanceMeters = 0.0
    /// Points retenus, pour Santé et la simplification.
    public private(set) var accepted: [RunTrackPoint] = []
    public private(set) var lastMovementAt: Date?
    /// Distance cumulée à chaque point retenu, de même rang que `accepted`.
    private var cumulative: [Double] = []
    /// Instant interpolé du passage de chaque multiple de 1 000 m.
    private var crossings: [Date] = []
    private var startsSegment = true

    public init(startedAt: Date) {
        self.startedAt = startedAt
    }

    /// Ajoute un point. Rend le numéro du km passé, s'il y en a un. Un point d'avant le départ (position en cache) est ignoré.
    @discardableResult
    public mutating func add(_ point: RunTrackPoint, isPaused: Bool) -> Int? {
        guard !isPaused, point.timestamp >= startedAt, point.horizontalAccuracy >= 0,
              point.horizontalAccuracy <= Self.maxHorizontalAccuracy else { return nil }
        guard let last = accepted.last else {
            retain(point, distance: 0)
            return nil
        }
        if startsSegment {
            retain(point, distance: 0)
            return nil
        }
        let step = Self.meters(from: last, to: point)
        let elapsed = point.timestamp.timeIntervalSince(last.timestamp)
        // Vitesse implicite contre le dernier point retenu : un point aberrant isolé n'écarte pas les suivants.
        guard elapsed > 0, step / elapsed <= Self.maxSpeed else { return nil }
        // Le bruit à l'arrêt ne devient pas le point de référence : le suivant se mesure toujours au dernier point retenu.
        guard step >= Self.minimumStep else { return nil }
        let before = distanceMeters
        retain(point, distance: step)
        lastMovementAt = point.timestamp
        return recordCrossings(from: last.timestamp, elapsed: elapsed, before: before, step: step)
    }

    /// Après une pause ou une reprise : le point suivant ouvre un nouveau segment, sans distance depuis le précédent.
    public mutating func breakSegment() {
        startsSegment = true
    }

    /// Une course rejouée depuis ses points bruts et ses pauses, comme si elle avait été construite en direct.
    public static func replay(startedAt: Date, points: [RunTrackPoint], pauses: [RunPause]) -> RunTrackBuilder {
        var builder = RunTrackBuilder(startedAt: startedAt)
        var wasPaused = false
        for point in points {
            let paused = pauses.contains { point.timestamp >= $0.start && point.timestamp < ($0.end ?? .distantFuture) }
            if paused != wasPaused {
                builder.breakSegment()
                wasPaused = paused
            }
            builder.add(point, isPaused: paused)
        }
        return builder
    }

    // MARK: Temps par km

    /// Un temps par km passé, pauses retirées ; le dernier km partiel va jusqu'à `end`.
    /// Un reste de moins de 10 m après le dernier km n'est pas un km partiel (bruit GPS), sauf dans le premier km,
    /// où la course en cours rend toujours un seul temps partiel.
    public func splits(pauses: [RunPause], end: Date) -> [RunSplit] {
        var splits: [RunSplit] = []
        var previous = 0.0
        for (index, crossing) in crossings.enumerated() {
            let moving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: crossing)
            splits.append(RunSplit(kilometer: index + 1, seconds: moving - previous, distanceMeters: Self.kilometer))
            previous = moving
        }
        let partial = distanceMeters - Double(crossings.count) * Self.kilometer
        if partial >= Self.minPartialMeters || (crossings.isEmpty && partial > 0) {
            let moving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: end)
            splits.append(RunSplit(kilometer: crossings.count + 1, seconds: max(0, moving - previous), distanceMeters: partial))
        }
        return splits
    }

    // MARK: Meilleurs segments

    /// Le temps en mouvement et la distance cumulée à chaque point retenu, pour chercher les meilleurs segments : les pauses ne
    /// comptent ni en temps ni en distance.
    public func segmentSamples(pauses: [RunPause]) -> [RunSegmentSample] {
        zip(accepted, cumulative).map { point, meters in
            RunSegmentSample(seconds: RunClock.movingSeconds(from: startedAt, pauses: pauses, at: point.timestamp), meters: meters)
        }
    }

    // MARK: Allures

    /// Allure du km en cours (s/km). Sous 100 m dans le km, celle des 30 dernières secondes en mouvement.
    public func currentKilometerPace(pauses: [RunPause], at date: Date) -> Int? {
        let moving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: date)
        let lastCrossing = crossings.last.map { RunClock.movingSeconds(from: startedAt, pauses: pauses, at: $0) } ?? 0
        let meters = distanceMeters - Double(crossings.count) * Self.kilometer
        if meters >= Self.shortKilometer { return Self.pace(seconds: moving - lastCrossing, meters: meters) }
        guard moving >= Self.paceWindow else { return nil }
        let windowMeters = distanceMeters - distance(atMovingSeconds: moving - Self.paceWindow, pauses: pauses)
        guard windowMeters >= Self.minWindowMeters else { return nil }
        return Self.pace(seconds: Self.paceWindow, meters: windowMeters)
    }

    /// Allure moyenne depuis le départ (s/km) ; `nil` sous 50 m.
    public func averagePace(pauses: [RunPause], at date: Date) -> Int? {
        guard distanceMeters >= Self.minAveragePaceMeters else { return nil }
        return Self.pace(seconds: RunClock.movingSeconds(from: startedAt, pauses: pauses, at: date), meters: distanceMeters)
    }

    // MARK: Dénivelé

    /// Dénivelé positif (m), avec hystérésis de 3 m sur les points à altitude fiable (≤ 10 m) ; `nil` si moins de la moitié le sont.
    public func elevationGainMeters() -> Double? {
        let altitudes = accepted.compactMap { point -> Double? in
            guard let altitude = point.altitude, let accuracy = point.verticalAccuracy,
                  accuracy >= 0, accuracy <= Self.maxVerticalAccuracy else { return nil }
            return altitude
        }
        guard !accepted.isEmpty, altitudes.count * 2 >= accepted.count, let first = altitudes.first else { return nil }
        var gain = 0.0
        var climbing = false
        var low = first
        var high = first
        for altitude in altitudes.dropFirst() {
            if climbing {
                if altitude > high {
                    gain += altitude - high
                    high = altitude
                } else if high - altitude >= Self.elevationHysteresis {
                    climbing = false
                    low = altitude
                }
            } else {
                low = min(low, altitude)
                if altitude - low >= Self.elevationHysteresis {
                    climbing = true
                    gain += altitude - low
                    high = altitude
                }
            }
        }
        return gain
    }

    // MARK: Internes

    private mutating func retain(_ point: RunTrackPoint, distance step: Double) {
        startsSegment = false
        distanceMeters += step
        accepted.append(point)
        cumulative.append(distanceMeters)
    }

    /// Note les passages de km entre le point précédent et celui qu'on vient de retenir ; rend le dernier numéro passé.
    private mutating func recordCrossings(from previousTime: Date, elapsed: TimeInterval, before: Double, step: Double) -> Int? {
        var crossed: Int?
        var next = crossings.count + 1
        while Double(next) * Self.kilometer <= distanceMeters {
            let fraction = (Double(next) * Self.kilometer - before) / step
            crossings.append(previousTime.addingTimeInterval(fraction * elapsed))
            crossed = next
            next += 1
        }
        return crossed
    }

    /// Distance cumulée à l'instant en mouvement `seconds`, interpolée entre deux points retenus.
    private func distance(atMovingSeconds seconds: Double, pauses: [RunPause]) -> Double {
        var upper = accepted.count - 1
        while upper > 0 {
            let lowerMoving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: accepted[upper - 1].timestamp)
            if lowerMoving <= seconds { break }
            upper -= 1
        }
        guard upper > 0 else { return 0 }
        let lowerMoving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: accepted[upper - 1].timestamp)
        let upperMoving = RunClock.movingSeconds(from: startedAt, pauses: pauses, at: accepted[upper].timestamp)
        guard upperMoving > lowerMoving else { return cumulative[upper] }
        let fraction = min(1, max(0, (seconds - lowerMoving) / (upperMoving - lowerMoving)))
        return cumulative[upper - 1] + fraction * (cumulative[upper] - cumulative[upper - 1])
    }

    private static func pace(seconds: Double, meters: Double) -> Int? {
        guard meters > 0, seconds > 0 else { return nil }
        return Int((seconds / meters * kilometer).rounded())
    }

    /// Distance haversine entre deux points, en mètres.
    private static func meters(from origin: RunTrackPoint, to target: RunTrackPoint) -> Double {
        let latA = origin.latitude * .pi / 180
        let latB = target.latitude * .pi / 180
        let deltaLat = latB - latA
        let deltaLon = (target.longitude - origin.longitude) * .pi / 180
        let haversine = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(latA) * cos(latB) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(haversine)))
    }
}
