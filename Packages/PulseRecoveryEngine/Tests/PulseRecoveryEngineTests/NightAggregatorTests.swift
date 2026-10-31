import Foundation
import PulseDomain
import Testing
@testable import PulseRecoveryEngine

@Suite struct NightAggregatorTests {
    let aggregator = NightAggregator(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 20)
    let d = TestCalendar.date

    /// Nuit du 19 au 20 novembre : 450 min endormi dont 90 profond, une pause éveillée de 10 min.
    var typicalSleep: [SleepInterval] {
        [SleepInterval(start: d(2026, 11, 19, 23, 10), end: d(2026, 11, 20, 1, 0), stage: .core),
         .init(start: d(2026, 11, 20, 1, 0), end: d(2026, 11, 20, 2, 30), stage: .deep),
         .init(start: d(2026, 11, 20, 2, 30), end: d(2026, 11, 20, 3, 30), stage: .rem),
         .init(start: d(2026, 11, 20, 3, 30), end: d(2026, 11, 20, 3, 40), stage: .awake),
         .init(start: d(2026, 11, 20, 3, 40), end: d(2026, 11, 20, 6, 50), stage: .core)]
    }

    var typicalSDNN: [TimedSample] {
        [TimedSample(date: d(2026, 11, 19, 22, 0), value: 40), .init(date: d(2026, 11, 20, 0, 30), value: 48),
         .init(date: d(2026, 11, 20, 2, 0), value: 52), .init(date: d(2026, 11, 20, 5, 0), value: 50),
         .init(date: d(2026, 11, 20, 9, 0), value: 70)]
    }

    @Test func typicalNight() {
        let rhr = [TimedSample(date: d(2026, 11, 20, 10, 0), value: 49)]
        let n = aggregator.night(for: day, sdnn: typicalSDNN, restingHeartRate: rhr, sleep: typicalSleep)
        #expect(n == NightSample(day: day, sdnnMs: 50, restingHeartRate: 49, sleep: .init(asleepMinutes: 450, deepMinutes: 90)))
    }

    @Test func noSleepFallsBackToMidnightToEight() {
        let sdnn = [TimedSample(date: d(2026, 11, 20, 0, 30), value: 48), .init(date: d(2026, 11, 20, 5, 0), value: 50),
                    .init(date: d(2026, 11, 20, 9, 0), value: 70)]
        let n = aggregator.night(for: day, sdnn: sdnn, restingHeartRate: [], sleep: [])
        #expect(n.sdnnMs == 49)
        #expect(n.sleep == nil)
        #expect(n.restingHeartRate == nil)
    }

    @Test func unspecifiedSleepHasNoDeepMinutes() {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: [], sleep: sleep)
        #expect(n.sleep == SleepSummary(asleepMinutes: 480, deepMinutes: nil))
    }

    @Test func overlappingSourcesAreMergedNotSummed() {
        let n = aggregator.night(for: day, sdnn: [], restingHeartRate: [], sleep: typicalSleep + typicalSleep)
        #expect(n.sleep == SleepSummary(asleepMinutes: 450, deepMinutes: 90))
    }

    @Test func dstNightUsesCalendar() {
        // Nuit du 24 au 25 octobre 2026 : retour à l'heure d'hiver, 3 h → 2 h. La nuit dure 9 h réelles.
        let wakeDay = TestCalendar.day(2026, 10, 25)
        let bedtime = d(2026, 10, 24, 23, 0)
        let sleep = [SleepInterval(start: bedtime, end: d(2026, 10, 25, 7, 0), stage: .core)]
        let sdnn = [TimedSample(date: bedtime.addingTimeInterval(3.5 * 3600), value: 55)] // 02:30 heure d'hiver
        let n = aggregator.night(for: wakeDay, sdnn: sdnn, restingHeartRate: [], sleep: sleep)
        #expect(n.sleep?.asleepMinutes == 540)
        #expect(n.sdnnMs == 55)
    }

    @Test func outOfRangeSDNNIgnored() {
        let junk = [TimedSample(date: d(2026, 11, 20, 3, 0), value: 0), .init(date: d(2026, 11, 20, 3, 10), value: 350)]
        let valid = TimedSample(date: d(2026, 11, 20, 3, 20), value: 50)
        #expect(aggregator.night(for: day, sdnn: junk + [valid], restingHeartRate: [], sleep: []).sdnnMs == 50)
        #expect(aggregator.night(for: day, sdnn: junk, restingHeartRate: [], sleep: []).sdnnMs == nil)
    }

    @Test func restingHeartRateOutsideDayIsNil() {
        let rhr = [TimedSample(date: d(2026, 11, 19, 23, 0), value: 49)]
        #expect(aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, sleep: []).restingHeartRate == nil)
    }

    @Test func restingHeartRateTakesLastSampleOfDay() {
        let rhr = [TimedSample(date: d(2026, 11, 20, 8, 0), value: 51), .init(date: d(2026, 11, 20, 10, 0), value: 49)]
        #expect(aggregator.night(for: day, sdnn: [], restingHeartRate: rhr, sleep: []).restingHeartRate == 49)
    }

    @Test func nightsBuildsOneSamplePerDay() {
        let days = [TestCalendar.day(2026, 11, 19), day]
        let nights = aggregator.nights(days: days, sdnn: typicalSDNN, restingHeartRate: [], sleep: typicalSleep)
        #expect(nights.map(\.day) == days)
        #expect(nights[0].sleep == nil)
        #expect(nights[1].sleep?.asleepMinutes == 450)
    }
}
