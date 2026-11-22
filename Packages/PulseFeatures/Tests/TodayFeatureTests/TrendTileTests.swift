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
        #expect(tiles[0].values.last == 56)
    }

    @Test func spokenValuesSayTheirUnitsInFull() {
        #expect(TrendTile.spokenValue(.hrv, 44) == "44 millisecondes")
        #expect(TrendTile.spokenValue(.hrv, 1) == "1 milliseconde")
        #expect(TrendTile.spokenValue(.restingHeartRate, 54) == "54 battements par minute")
        #expect(TrendTile.spokenValue(.restingHeartRate, 1) == "1 battement par minute")
        #expect(TrendTile.spokenValue(.sleep, 432) == "7 heures 12 minutes")
        #expect(TrendTile.spokenValue(.sleep, 480) == "8 heures")
    }

    private func series(old: Double?, new: Double?) -> [Double?] {
        Array(repeating: old, count: 7) + Array(repeating: new, count: 7)
    }

    @Test func directionComparesTheLastWeekWithTheOneBefore() {
        #expect(TrendTile.direction(of: series(old: 40, new: 48)) == .up)
        #expect(TrendTile.direction(of: series(old: 50, new: 44)) == .down)
        #expect(TrendTile.direction(of: series(old: 50, new: 51)) == .steady)
        // Moins de 5 % d'écart : stable, des deux côtés.
        #expect(TrendTile.direction(of: series(old: 50, new: 52.4)) == .steady)
        #expect(TrendTile.direction(of: series(old: 50, new: 47.6)) == .steady)
        #expect(TrendTile.direction(of: series(old: 50, new: 52.6)) == .up)
    }

    @Test func directionNeedsEnoughMeasuresOnBothSides() {
        #expect(TrendTile.direction(of: series(old: nil, new: 50)) == nil)
        #expect(TrendTile.direction(of: series(old: 50, new: nil)) == nil)
        #expect(TrendTile.direction(of: []) == nil)
        var thin = series(old: 50, new: 60)
        for index in [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13] { thin[index] = nil }
        #expect(TrendTile.direction(of: thin) == nil)
        #expect(TrendTile.direction(of: series(old: 0, new: 10)) == nil)
    }

    @Test func directionWordsAreSpoken() {
        #expect(TrendTile.Direction.up.spoken == "tendance en hausse")
        #expect(TrendTile.Direction.down.spoken == "tendance en baisse")
        #expect(TrendTile.Direction.steady.spoken == "tendance stable")
    }

    @Test func labelsSpeakTheTitleTheValueAndTheTrend() async {
        let tiles = await tiles(.goodNight)
        for tile in tiles {
            for forbidden in [" ms", "bpm", "FC ", "\u{2014}"] { #expect(!tile.accessibilityLabel.contains(forbidden)) }
        }
        #expect(tiles[1].accessibilityLabel.hasPrefix("Fréquence cardiaque au repos, 14 jours, dernière valeur 48 battements par minute"))
        #expect(tiles[0].accessibilityLabel.hasPrefix("Variabilité, 14 jours, dernière valeur 56 millisecondes"))
        #expect(tiles[2].accessibilityLabel.hasPrefix("Sommeil, 14 jours, moyenne 8 heures"))
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
