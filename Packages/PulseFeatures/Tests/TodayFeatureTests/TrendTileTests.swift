import Foundation
import PulseDomain
import PulseServices
import Testing
@testable import TodayFeature

@MainActor
struct TrendTileTests {
    private let monday = TodayClock.date("2026-11-02T08:00")
    private var calendar: Calendar { TodayClock.calendar }

    private func nights(_ scenario: HealthScenario) async -> [NightSample] {
        let fixture = TodayFixture(scenario: scenario)
        return await fixture.environment.refresher.refresh(origin: .foreground).nights
    }

    private func tiles(_ scenario: HealthScenario) async -> [TrendTile] {
        TrendTile.make(nights: await nights(scenario), day: calendar.startOfDay(for: monday), calendar: calendar)
    }

    @Test func threeTilesOverFourteenDays() async {
        let tiles = await tiles(.goodNight)
        #expect(tiles.map(\.title) == ["Variabilité, 14 jours", "FC repos, 14 jours", "Sommeil, 14 jours"])
        #expect(tiles.map(\.factor) == [.hrv, .restingHeartRate, .sleep])
        #expect(tiles.allSatisfy { $0.values.count == 14 })
    }

    @Test func goodNightTexts() async {
        let tiles = await tiles(.goodNight)
        #expect(tiles.map(\.valueText) == ["56 ms", "48 bpm", "8 h"])
        #expect(tiles[0].accessibilityLabel == "Variabilité, 14 jours, dernière valeur 56 ms")
        #expect(tiles[1].accessibilityLabel == "FC repos, 14 jours, dernière valeur 48 bpm")
        #expect(tiles[2].accessibilityLabel == "Sommeil, 14 jours, moyenne 8 h")
        #expect(tiles[0].values.last == 56)
    }

    @Test func missingHRVKeepsTheLastValue() async throws {
        let tiles = await tiles(.missingHRV)
        let last = try #require(tiles[0].values.last)
        #expect(last == nil)
        #expect(tiles[0].valueText == "52 ms")
    }

    @Test func noDataShowsDashes() async {
        let tiles = await tiles(.noData)
        #expect(tiles.map(\.valueText) == ["\u{2014}", "\u{2014}", "\u{2014}"])
        #expect(tiles.allSatisfy { $0.values.allSatisfy { $0 == nil } })
        #expect(tiles[0].accessibilityLabel == "Variabilité, 14 jours, aucune donnée")
    }

    @Test func gapsStayNilAndSleepAverages() {
        let today = calendar.startOfDay(for: monday)
        func night(_ offset: Int, sdnn: Double?, rhr: Double?, sleep: Int?) -> NightSample {
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let summary = sleep.map { SleepSummary(asleepMinutes: $0, deepMinutes: nil) }
            return NightSample(day: day, sdnnMs: sdnn, restingHeartRate: rhr, sleep: summary)
        }
        let samples = [
            night(0, sdnn: 0, rhr: 54, sleep: 400), night(1, sdnn: 44, rhr: nil, sleep: 464),
            night(13, sdnn: 40, rhr: 50, sleep: nil), night(14, sdnn: 99, rhr: 99, sleep: 999)
        ]
        let tiles = TrendTile.make(nights: samples, day: today, calendar: calendar)
        #expect(tiles[0].values.count == 14 && tiles[0].values[0] == 40 && tiles[0].values[12] == 44 && tiles[0].values[13] == nil)
        #expect(tiles[0].valueText == "44 ms")
        #expect(tiles[1].valueText == "54 bpm")
        #expect(tiles[2].valueText == "7 h 12")
    }
}
