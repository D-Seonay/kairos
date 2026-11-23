import Foundation
import PulseDomain

/// Traces GPS déterministes pour les tests de course : départ à (48.8566, 2.3522), cap au nord, 1 point par seconde.
/// L'écart latéral vaut `3 * sin(t / 10)` m, un bruit lent comme celui de Core Location.
enum RunTraceFactory {
    static let originLatitude = 48.8566
    static let originLongitude = 2.3522
    /// 1° de latitude, en mètres.
    static let metersPerDegree = 111_320.0

    /// Un point à `northMeters` au nord du départ, à la seconde `second` de la trace.
    static func point(northMeters: Double, second: Int, start: Date, lateralOffset: Double = 0, accuracy: Double = 5,
                      verticalAccuracy: Double = 4) -> RunTrackPoint {
        let lateral = 3 * sin(Double(second) / 10) + lateralOffset
        let latitude = originLatitude + northMeters / metersPerDegree
        let longitude = originLongitude + lateral / (metersPerDegree * cos(originLatitude * .pi / 180))
        return RunTrackPoint(
            timestamp: start.addingTimeInterval(Double(second)), latitude: latitude, longitude: longitude,
            altitude: 0.02 * Double(second), horizontalAccuracy: accuracy, verticalAccuracy: verticalAccuracy)
    }

    /// Trace propre : précision 5 m, altitude montant de 0,02 m/s, `verticalAccuracy` 4.
    static func clean(meters: Double, speed: Double, start: Date, verticalAccuracy: Double = 4) -> [RunTrackPoint] {
        legs([(meters, speed)], start: start, verticalAccuracy: verticalAccuracy)
    }

    /// Une trace propre faite de tronçons `(mètres, vitesse en m/s)` bout à bout.
    static func legs(_ legs: [(meters: Double, speed: Double)], start: Date, verticalAccuracy: Double = 4) -> [RunTrackPoint] {
        var points = [point(northMeters: 0, second: 0, start: start, verticalAccuracy: verticalAccuracy)]
        var north = 0.0
        for leg in legs {
            let seconds = Int(leg.meters / leg.speed)
            for _ in 0..<seconds {
                north += leg.speed
                points.append(point(northMeters: north, second: points.count, start: start, verticalAccuracy: verticalAccuracy))
            }
        }
        return points
    }

    /// La trace propre, avec 20 points consécutifs à 65 m de précision (et très décalés) puis un point isolé
    /// déplacé de 300 m vers l'avant au milieu ; la trace reprend ensuite son chemin normal.
    static func tunnel(meters: Double, speed: Double, start: Date) -> [RunTrackPoint] {
        var points = clean(meters: meters, speed: speed, start: start)
        let degradedStart = points.count / 4
        for index in degradedStart..<(degradedStart + 20) {
            points[index] = point(
                northMeters: speed * Double(index), second: index, start: start,
                lateralOffset: 40 * sin(Double(index)), accuracy: 65)
        }
        let jump = points.count / 2
        points[jump] = point(northMeters: speed * Double(jump) + 300, second: jump, start: start)
        return points
    }

    /// 2 000 m, puis 20 minutes où les points piétinent sur place (en pause), puis 1 000 m, à 3 m/s.
    static func withPause(start: Date) -> (points: [RunTrackPoint], pause: RunPause) {
        let speed = 3.0
        var points = clean(meters: 2_000, speed: speed, start: start)
        let pauseStartSecond = points.count
        let standingNorth = speed * Double(pauseStartSecond - 1)
        for step in 0..<1_200 {
            points.append(point(
                northMeters: standingNorth, second: pauseStartSecond + step, start: start, lateralOffset: sin(Double(step))))
        }
        let resumeSecond = pauseStartSecond + 1_200
        for step in 0..<(1_000 / Int(speed)) {
            let active = pauseStartSecond + step
            points.append(point(northMeters: speed * Double(active), second: resumeSecond + step, start: start))
        }
        let pause = RunPause(
            start: start.addingTimeInterval(Double(pauseStartSecond)), end: start.addingTimeInterval(Double(resumeSecond)))
        return (points, pause)
    }
}
