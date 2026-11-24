import Foundation
@testable import NightFeature
import PulseDomain
import Testing

struct NightChartDescriptorTests {
    private let date = NightFixtures.date

    @Test func hypnogramDescriptorHasOneSeriesPerPresentStage() {
        var night = NightFixtures.typicalNight()
        night.segments = [SleepSegment(start: date(2026, 11, 19, 23, 10), end: date(2026, 11, 20, 1, 0), stage: .core),
                          .init(start: date(2026, 11, 20, 1, 0), end: date(2026, 11, 20, 2, 30), stage: .deep),
                          .init(start: date(2026, 11, 20, 2, 30), end: date(2026, 11, 20, 3, 30), stage: .rem),
                          .init(start: date(2026, 11, 20, 3, 30), end: date(2026, 11, 20, 3, 40), stage: .awake),
                          .init(start: date(2026, 11, 20, 3, 40), end: date(2026, 11, 20, 6, 50), stage: .core)]
        let series = NightChartDescriptor.series(night)
        #expect(series.map(\.name) == ["Profond", "Léger", "Paradoxal", "Éveil"])
        #expect(series.first { $0.name == "Léger" }?.points.map(\.y) == [110, 190])
    }

    @Test func unspecifiedRestOfAStagedNightIsItsOwnSeries() {
        var night = NightFixtures.typicalNight(unspecified: 60)
        night.segments = [SleepSegment(start: date(2026, 11, 19, 23, 10), end: date(2026, 11, 20, 1, 0), stage: .core),
                          .init(start: date(2026, 11, 20, 5, 50), end: date(2026, 11, 20, 6, 50), stage: .asleepUnspecified)]
        let series = NightChartDescriptor.series(night)
        #expect(series.map(\.name) == ["Léger", "Sans phase"])
        #expect(series.first { $0.name == "Léger" }?.points.map(\.y) == [110])
    }

    @Test func unstagedDescriptorHasAsleepAndAwake() {
        var night = NightFixtures.typicalNight(hasStages: false)
        night.segments = [SleepSegment(start: date(2026, 11, 19, 23, 0), end: date(2026, 11, 20, 3, 0), stage: .asleepUnspecified),
                          .init(start: date(2026, 11, 20, 3, 0), end: date(2026, 11, 20, 3, 15), stage: .awake),
                          .init(start: date(2026, 11, 20, 3, 15), end: date(2026, 11, 20, 7, 0), stage: .asleepUnspecified)]
        #expect(NightChartDescriptor.series(night).map(\.name) == ["Endormi", "Éveil"])
    }
}
