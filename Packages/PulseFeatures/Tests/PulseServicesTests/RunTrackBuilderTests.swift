import Foundation
import PulseDomain
import Testing

@testable import PulseServices

struct RunTrackBuilderTests {
    private let start = TestClock.date("2026-11-24T07:00")

    private func isPaused(_ point: RunTrackPoint, in pauses: [RunPause]) -> Bool {
        pauses.contains { point.timestamp >= $0.start && point.timestamp < ($0.end ?? .distantFuture) }
    }

    /// Ajoute les points un par un, comme le service : `breakSegment()` à chaque pause et à chaque reprise.
    private func live(_ points: [RunTrackPoint], pauses: [RunPause] = []) -> RunTrackBuilder {
        var builder = RunTrackBuilder(startedAt: start)
        var wasPaused = false
        for point in points {
            let paused = isPaused(point, in: pauses)
            if paused != wasPaused {
                builder.breakSegment()
                wasPaused = paused
            }
            _ = builder.add(point, isPaused: paused)
        }
        return builder
    }

    private func end(of points: [RunTrackPoint]) -> Date { points.last?.timestamp ?? start }

    @Test func cleanTraceIsWithinOnePercent() {
        let points = RunTraceFactory.clean(meters: 5_000, speed: 3, start: start)
        let builder = live(points)
        #expect(abs(builder.distanceMeters - 5_000) / 5_000 < 0.01)
        let splits = builder.splits(pauses: [], end: end(of: points))
        #expect(splits.count == 5)
        for split in splits { #expect(split.seconds > 325 && split.seconds < 342) }
        #expect(splits.map(\.kilometer) == [1, 2, 3, 4, 5])
    }

    @Test func noisyTraceIsWithinThreePercent() throws {
        let points = RunTraceFactory.tunnel(meters: 5_000, speed: 3, start: start)
        let builder = live(points)
        #expect(abs(builder.distanceMeters - 5_000) / 5_000 < 0.03)
        // Ni les 20 points imprécis ni le saut ne sont retenus, mais les points qui suivent le saut le sont de nouveau.
        let jump = points[points.count / 2]
        #expect(!builder.accepted.contains(jump))
        #expect(builder.accepted.allSatisfy { $0.horizontalAccuracy <= RunTrackBuilder.maxHorizontalAccuracy })
        let afterJump = builder.accepted.filter { $0.timestamp > jump.timestamp }
        #expect(afterJump.count > 100)
        let lastAccepted = try #require(afterJump.last)
        #expect(end(of: points).timeIntervalSince(lastAccepted.timestamp) < 10)
    }

    /// Le premier point livré peut dater d'avant le départ (position en cache, 200 m plus loin) : il n'ouvre pas la course.
    @Test func pointsBeforeStartAreIgnored() throws {
        let cached = RunTraceFactory.point(northMeters: -200, second: -5, start: start)
        let points = RunTraceFactory.clean(meters: 1_000, speed: 3, start: start)
        let builder = live([cached] + points)
        #expect(abs(builder.distanceMeters - 1_000) / 1_000 < 0.01)
        #expect(!builder.accepted.contains(cached))
        #expect(try #require(builder.accepted.first).timestamp == start)
    }

    @Test func pausedPointsAddNoDistance() {
        let trace = RunTraceFactory.withPause(start: start)
        let builder = live(trace.points, pauses: [trace.pause])
        #expect(abs(builder.distanceMeters - 3_000) / 3_000 < 0.01)
        #expect(!builder.accepted.contains { isPaused($0, in: [trace.pause]) })
    }

    @Test func splitsExcludePausedTime() {
        let trace = RunTraceFactory.withPause(start: start)
        let builder = live(trace.points, pauses: [trace.pause])
        let splits = builder.splits(pauses: [trace.pause], end: end(of: trace.points))
        #expect(splits.count >= 3)
        #expect(splits[2].seconds < 400)
        for split in splits { #expect(split.seconds < 400) }
    }

    @Test func currentKilometerPaceUsesLastThirtySecondsUnderAHundredMetres() {
        let points = RunTraceFactory.clean(meters: 1_050, speed: 3, start: start)
        let builder = live(points)
        let pace = builder.currentKilometerPace(pauses: [], at: end(of: points))
        #expect(pace != nil)
        if let pace { #expect(abs(pace - 333) <= 3) }
    }

    @Test func currentKilometerPaceIgnoresTheSprintStartedAfterTheKilometre() {
        // 1 000 m à 3 m/s, puis 50 m à 5 m/s : depuis le km, 200 s/km ; sur 30 s en mouvement, 273 s/km.
        let points = RunTraceFactory.legs([(1_000, 3), (50, 5)], start: start)
        let builder = live(points)
        let pace = builder.currentKilometerPace(pauses: [], at: end(of: points))
        #expect(pace != nil)
        if let pace { #expect(pace > 260 && pace < 290) }
    }

    @Test func currentKilometerPaceIsNilWhenTheWindowIsTooShort() {
        // 25 s à 0,5 m/s : moins de 20 m sur les 30 s.
        let points = RunTraceFactory.legs([(12, 0.5), (12, 0.5)], start: start)
        let builder = live(points)
        #expect(builder.currentKilometerPace(pauses: [], at: end(of: points)) == nil)
    }

    @Test func currentKilometerPaceUsesTheKilometreAverageBeyondAHundredMetres() {
        let points = RunTraceFactory.clean(meters: 600, speed: 3, start: start)
        let builder = live(points)
        let pace = builder.currentKilometerPace(pauses: [], at: end(of: points))
        #expect(pace != nil)
        if let pace { #expect(abs(pace - 333) <= 4) }
    }

    @Test func averagePaceNeedsFiftyMetres() {
        let short = RunTraceFactory.clean(meters: 30, speed: 3, start: start)
        #expect(live(short).averagePace(pauses: [], at: end(of: short)) == nil)
        let long = RunTraceFactory.clean(meters: 3_000, speed: 3, start: start)
        let pace = live(long).averagePace(pauses: [], at: end(of: long))
        #expect(pace != nil)
        if let pace { #expect(abs(pace - 333) <= 4) }
    }

    @Test func kilometerCrossingIsReturnedOnce() {
        var builder = RunTrackBuilder(startedAt: start)
        let points = RunTraceFactory.clean(meters: 1_200, speed: 3, start: start)
        let crossings = points.compactMap { builder.add($0, isPaused: false) }
        #expect(crossings == [1])
    }

    @Test func lastMovementIgnoresStandingStill() throws {
        var points = RunTraceFactory.clean(meters: 500, speed: 3, start: start)
        let lastMoving = try #require(points.last)
        for step in 1...30 {
            var still = lastMoving
            still.timestamp = lastMoving.timestamp.addingTimeInterval(Double(step))
            points.append(still)
        }
        let builder = live(points)
        #expect(builder.lastMovementAt == lastMoving.timestamp)
    }

    @Test func elevationGainNeedsReliableAltitude() throws {
        let points = RunTraceFactory.clean(meters: 1_800, speed: 3, start: start)
        let gain = try #require(live(points).elevationGainMeters())
        #expect(abs(gain - 12) <= 3)
        let unreliable = RunTraceFactory.clean(meters: 1_800, speed: 3, start: start, verticalAccuracy: 30)
        #expect(live(unreliable).elevationGainMeters() == nil)
    }

    @Test func elevationHysteresisIgnoresSmallBumps() {
        var builder = RunTrackBuilder(startedAt: start)
        let altitudes = [0.0, 2, 0, 2, 1, 2.5, 0, 5, 1.5, 6]
        for (second, altitude) in altitudes.enumerated() {
            var point = RunTraceFactory.point(northMeters: Double(second) * 6, second: second, start: start)
            point.altitude = altitude
            _ = builder.add(point, isPaused: false)
        }
        // Creux à 0 → pic à 5 (+5), creux à 1,5 → 6 (+4,5).
        #expect(builder.elevationGainMeters() == 9.5)
    }

    @Test func standingJitterAddsNoDistance() throws {
        var points = RunTraceFactory.clean(meters: 500, speed: 3, start: start)
        let spot = try #require(points.last)
        var builder = live(points)
        let distanceBefore = builder.distanceMeters
        let movedAt = try #require(builder.lastMovementAt)
        let metersPerDegree = RunTraceFactory.metersPerDegree
        for step in 1...1_800 {
            var still = spot
            still.timestamp = spot.timestamp.addingTimeInterval(Double(step))
            still.latitude += 3 * sin(Double(step)) / metersPerDegree
            still.longitude += 3 * cos(Double(step) * 0.7) / (metersPerDegree * cos(spot.latitude * .pi / 180))
            points.append(still)
            builder.add(still, isPaused: false)
        }
        #expect(builder.distanceMeters - distanceBefore < 10)
        #expect(builder.lastMovementAt == movedAt)
        #expect(builder.accepted.count == live(Array(points.prefix(points.count - 1_800))).accepted.count)
    }

    @Test func replayMatchesLiveBuilding() {
        let trace = RunTraceFactory.withPause(start: start)
        let pauses = [trace.pause]
        let liveBuilder = live(trace.points, pauses: pauses)
        let replayed = RunTrackBuilder.replay(startedAt: start, points: trace.points, pauses: pauses)
        let finish = end(of: trace.points)
        #expect(replayed.distanceMeters == liveBuilder.distanceMeters)
        #expect(replayed.splits(pauses: pauses, end: finish) == liveBuilder.splits(pauses: pauses, end: finish))
    }

    @Test func movingSecondsRemovesPauses() {
        let pause = RunPause(start: start.addingTimeInterval(100), end: start.addingTimeInterval(160))
        #expect(RunClock.movingSeconds(from: start, pauses: [pause], at: start.addingTimeInterval(300)) == 240)
        #expect(RunClock.movingSeconds(from: start, pauses: [pause], at: start.addingTimeInterval(130)) == 100)
        let open = RunPause(start: start.addingTimeInterval(100))
        #expect(RunClock.movingSeconds(from: start, pauses: [open], at: start.addingTimeInterval(300)) == 100)
    }

    @Test func partialSplitInTheFirstKilometre() {
        let points = RunTraceFactory.clean(meters: 400, speed: 3, start: start)
        let splits = live(points).splits(pauses: [], end: end(of: points))
        #expect(splits.count == 1)
        #expect(splits.first?.kilometer == 1)
        #expect((splits.first?.distanceMeters ?? 0) > 390)
    }
}
