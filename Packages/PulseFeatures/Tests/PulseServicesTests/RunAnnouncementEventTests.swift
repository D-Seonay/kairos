import PulseDomain
import Testing

@testable import PulseServices

struct RunAnnouncementEventTests {
    private let splits = [330.0, 335, 332].enumerated().map {
        RunSplit(kilometer: $0.offset + 1, seconds: $0.element, distanceMeters: 1_000)
    }

    @Test func kilometerEventCarriesSplit() {
        let events = RunAnnouncementEvent.events(
            kilometer: 3, splits: splits, movingSeconds: 997, previousProgress: nil, progress: nil)
        #expect(events == [.kilometer(3, movingSeconds: 997, splitSeconds: 332)])
    }

    @Test func kilometerWithoutSplitIsOmitted() {
        let events = RunAnnouncementEvent.events(
            kilometer: 4, splits: splits, movingSeconds: 1_330, previousProgress: nil, progress: nil)
        #expect(events.isEmpty)
    }

    @Test func noKilometerMeansNoKilometerEvent() {
        let events = RunAnnouncementEvent.events(
            kilometer: nil, splits: splits, movingSeconds: 997, previousProgress: nil, progress: nil)
        #expect(events.isEmpty)
    }

    @Test func halfAndTargetFireOnCrossing() {
        func events(_ previous: Double?, _ current: Double?) -> [RunAnnouncementEvent] {
            RunAnnouncementEvent.events(
                kilometer: nil, splits: [], movingSeconds: 0, previousProgress: previous, progress: current)
        }
        #expect(events(0.49, 0.51) == [.halfTarget])
        #expect(events(0.99, 1.0) == [.targetReached])
        #expect(events(0.6, 0.7) == [])
        #expect(events(0.5, 0.6) == [])
        #expect(events(1.0, 1.1) == [])
        #expect(events(0.2, nil) == [])
        #expect(events(nil, 0.6) == [])
        #expect(events(nil, nil) == [])
    }

    @Test func crossingBothInOneUpdateKeepsOrder() {
        let events = RunAnnouncementEvent.events(
            kilometer: 1, splits: Array(splits.prefix(1)), movingSeconds: 330, previousProgress: 0.4, progress: 1.05)
        #expect(events == [.kilometer(1, movingSeconds: 330, splitSeconds: 330), .halfTarget, .targetReached])
    }
}
