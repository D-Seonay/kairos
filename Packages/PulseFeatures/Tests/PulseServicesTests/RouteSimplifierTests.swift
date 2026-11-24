import Foundation
import PulseDomain
import Testing

@testable import PulseServices

struct RouteSimplifierTests {
    private let start = TestClock.date("2026-11-24T07:00")
    private let metersPerDegree = RunTraceFactory.metersPerDegree

    /// Un point à (`east`, `north`) mètres du départ, à la seconde `second`.
    private func point(east: Double, north: Double, second: Int) -> RunTrackPoint {
        let longitude = RunTraceFactory.originLongitude
            + east / (metersPerDegree * cos(RunTraceFactory.originLatitude * .pi / 180))
        return RunTrackPoint(
            timestamp: start.addingTimeInterval(Double(second)),
            latitude: RunTraceFactory.originLatitude + north / metersPerDegree, longitude: longitude, horizontalAccuracy: 5)
    }

    /// Une heure de boucle : cercle de 400 m de rayon, 4 tours, 1 point par seconde.
    private func loop() -> [RunTrackPoint] {
        (0..<3_600).map { second in
            let angle = 4 * 2 * Double.pi * Double(second) / 3_600
            return point(east: 400 * cos(angle), north: 400 * sin(angle), second: second)
        }
    }

    /// Coordonnées locales (m) d'un point, autour du départ de la trace.
    private func local(_ point: RunTrackPoint) -> (x: Double, y: Double) {
        (
            (point.longitude - RunTraceFactory.originLongitude) * metersPerDegree * cos(RunTraceFactory.originLatitude * .pi / 180),
            (point.latitude - RunTraceFactory.originLatitude) * metersPerDegree
        )
    }

    private func distance(
        from point: (x: Double, y: Double), toSegment origin: (x: Double, y: Double), _ end: (x: Double, y: Double)
    ) -> Double {
        let dx = end.x - origin.x
        let dy = end.y - origin.y
        let lengthSquared = dx * dx + dy * dy
        let ratio = lengthSquared == 0 ? 0 : max(0, min(1, ((point.x - origin.x) * dx + (point.y - origin.y) * dy) / lengthSquared))
        return hypot(point.x - (origin.x + ratio * dx), point.y - (origin.y + ratio * dy))
    }

    @Test func straightLineKeepsTwoPoints() {
        let points = (0..<600).map { point(east: 0, north: Double($0) * 3, second: $0) }
        let simplified = RouteSimplifier.simplify(points)
        #expect(simplified.count == 2)
        #expect(simplified.first == points.first)
        #expect(simplified.last == points.last)
    }

    @Test func oneHourStaysUnderFiveHundredPoints() {
        let simplified = RouteSimplifier.simplify(loop())
        #expect(simplified.count < 500)
        #expect(simplified.count > 10)
    }

    @Test func simplifiedRouteStaysWithinTolerance() {
        let points = loop()
        let simplified = RouteSimplifier.simplify(points).map(local)
        for original in points.map(local) {
            let nearest = zip(simplified, simplified.dropFirst()).map { distance(from: original, toSegment: $0, $1) }.min() ?? .infinity
            #expect(nearest <= 5.5)
        }
    }

    @Test func shortRoutesAreReturnedAsIs() {
        #expect(RouteSimplifier.simplify([]).isEmpty)
        let two = [point(east: 0, north: 0, second: 0), point(east: 0, north: 50, second: 10)]
        #expect(RouteSimplifier.simplify(two) == two)
        #expect(RouteSimplifier.simplify(Array(two.prefix(1))) == Array(two.prefix(1)))
    }

    @Test func cornerIsKept() {
        let points = (0...100).map { point(east: 0, north: Double($0), second: $0) }
            + (1...100).map { point(east: Double($0), north: 100, second: 100 + $0) }
        let simplified = RouteSimplifier.simplify(points)
        #expect(simplified.count == 3)
        #expect(simplified[1] == points[100])
    }
}
