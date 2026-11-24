import Foundation
import PulseDomain
@testable import PulseRecoveryEngine
import Testing

@Suite struct NightSleepBuilderTests {
    let builder = NightSleepBuilder(calendar: TestCalendar.paris)
    let day = TestCalendar.day(2026, 11, 20)
    let d = TestCalendar.date

    /// Nuit du 19 au 20 novembre : 450 min endormi dont 90 profond, une pause éveillée de 10 min (fixture de NightAggregatorTests).
    var typicalSleep: [SleepInterval] {
        [SleepInterval(start: d(2026, 11, 19, 23, 10), end: d(2026, 11, 20, 1, 0), stage: .core),
         .init(start: d(2026, 11, 20, 1, 0), end: d(2026, 11, 20, 2, 30), stage: .deep),
         .init(start: d(2026, 11, 20, 2, 30), end: d(2026, 11, 20, 3, 30), stage: .rem),
         .init(start: d(2026, 11, 20, 3, 30), end: d(2026, 11, 20, 3, 40), stage: .awake),
         .init(start: d(2026, 11, 20, 3, 40), end: d(2026, 11, 20, 6, 50), stage: .core)]
    }

    @Test func typicalNight() throws {
        let night = try #require(builder.night(for: day, sleep: typicalSleep))
        #expect(night.day == day)
        #expect(night.fellAsleep == d(2026, 11, 19, 23, 10))
        #expect(night.wokeUp == d(2026, 11, 20, 6, 50))
        #expect(night.asleepMinutes == 450)
        #expect(night.deepMinutes == 90)
        #expect(night.remMinutes == 60)
        #expect(night.coreMinutes == 300)
        #expect(night.unspecifiedMinutes == 0)
        #expect(night.awakeMinutes == 10)
        #expect(night.awakenings == 1)
        #expect(night.segments.count == 5)
        #expect(night.hasStages)
        #expect(night.otherBlocks.isEmpty)
    }

    @Test func overlappingSourcesResolveByPriority() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .core),
                     .init(start: d(2026, 11, 20, 1, 0), end: d(2026, 11, 20, 2, 0), stage: .deep),
                     .init(start: d(2026, 11, 19, 22, 30), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.asleepMinutes == 510)
        #expect(night.deepMinutes == 60)
        #expect(night.coreMinutes == 420)
        #expect(night.unspecifiedMinutes == 30)
        #expect(night.segments.map(\.stage) == [.asleepUnspecified, .core, .deep, .core])
    }

    @Test func awakeningsShorterThanTwoMinutesAreNotCounted() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 3, 0), stage: .core),
                     .init(start: d(2026, 11, 20, 3, 0), end: d(2026, 11, 20, 3, 1), stage: .awake),
                     .init(start: d(2026, 11, 20, 3, 1), end: d(2026, 11, 20, 7, 0), stage: .core)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.awakenings == 0)
        #expect(night.awakeMinutes == 1)
    }

    @Test func gapWithoutSamplesIsNeitherAwakeNorAwakening() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 2, 0), stage: .core),
                     .init(start: d(2026, 11, 20, 2, 20), end: d(2026, 11, 20, 7, 0), stage: .core)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.awakeMinutes == 0)
        #expect(night.awakenings == 0)
        #expect(night.segments.count == 2)
        #expect(night.asleepMinutes == 460)
    }

    @Test func eveningNapIsAnOtherBlock() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 18, 5), end: d(2026, 11, 19, 18, 30), stage: .core),
                     .init(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .core)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.fellAsleep == d(2026, 11, 19, 23, 0))
        #expect(night.otherBlocks == [SleepBlock(start: d(2026, 11, 19, 18, 5), end: d(2026, 11, 19, 18, 30), asleepMinutes: 25)])
        #expect(night.asleepMinutes == 505)
        #expect(night.coreMinutes == 505)
    }

    @Test func awakeOutsideTheMainBlockIsDropped() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 22, 0), end: d(2026, 11, 19, 23, 0), stage: .awake),
                     .init(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .core),
                     .init(start: d(2026, 11, 20, 7, 0), end: d(2026, 11, 20, 7, 30), stage: .awake)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.awakeMinutes == 0)
        #expect(night.segments.count == 1)
    }

    @Test func unspecifiedOnlyHasNoStages() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 23, 0), end: d(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(!night.hasStages)
        #expect(night.unspecifiedMinutes == 480)
        #expect(night.deepMinutes == 0)
        #expect(night.coreMinutes == 0)
        #expect(night.remMinutes == 0)
    }

    @Test func noAsleepIntervalGivesNil() {
        let sleep = [SleepInterval(start: d(2026, 11, 19, 22, 30), end: d(2026, 11, 20, 7, 0), stage: .inBed),
                     .init(start: d(2026, 11, 20, 3, 0), end: d(2026, 11, 20, 3, 20), stage: .awake)]
        #expect(builder.night(for: day, sleep: sleep) == nil)
    }

    @Test func stageMinutesAddUpToAsleepDespiteRounding() throws {
        let sleep = [SleepInterval(start: d(2026, 11, 20, 1, 0).addingTimeInterval(30), end: d(2026, 11, 20, 1, 30), stage: .deep),
                     .init(start: d(2026, 11, 20, 1, 30), end: d(2026, 11, 20, 2, 0).addingTimeInterval(30), stage: .rem),
                     .init(start: d(2026, 11, 20, 2, 0).addingTimeInterval(30), end: d(2026, 11, 20, 2, 30), stage: .core)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.asleepMinutes == 90)
        #expect(night.deepMinutes == 30)
        #expect(night.deepMinutes + night.coreMinutes + night.remMinutes + night.unspecifiedMinutes == night.asleepMinutes)
    }

    /// 20 s de léger, puis deux plages de 30,5 min : les arrondis donneraient 31 + 31 + 0 pour un total de 61. Le reste va à la
    /// plus longue phase hors profond, jamais à une phase qui tomberait sous zéro.
    @Test func roundingResidueNeverBreaksTheSum() throws {
        let start = d(2026, 11, 20, 1, 0)
        let sleep = [SleepInterval(start: start, end: start.addingTimeInterval(20), stage: .core),
                     .init(start: start.addingTimeInterval(20), end: start.addingTimeInterval(20 + 1830), stage: .deep),
                     .init(start: start.addingTimeInterval(20 + 1830), end: start.addingTimeInterval(20 + 3660), stage: .rem)]
        let night = try #require(builder.night(for: day, sleep: sleep))
        #expect(night.asleepMinutes == 61)
        #expect(night.deepMinutes == 31)
        #expect(night.deepMinutes + night.coreMinutes + night.remMinutes + night.unspecifiedMinutes == night.asleepMinutes)
        #expect(night.coreMinutes >= 0 && night.remMinutes >= 0)
    }

    @Test func dstNightUsesCalendar() throws {
        let wakeDay = TestCalendar.day(2026, 10, 25)
        let sleep = [SleepInterval(start: d(2026, 10, 24, 23, 0), end: d(2026, 10, 25, 7, 0), stage: .core)]
        let night = try #require(builder.night(for: wakeDay, sleep: sleep))
        #expect(night.asleepMinutes == 540)
    }
}
