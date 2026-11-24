import Foundation
@testable import NightFeature
import PulseDomain
import PulseServices
import Testing

struct NightTextTests {
    private let calendar = NightFixtures.calendar

    @Test func titleWithinOneMonth() {
        #expect(NightText.title(NightFixtures.typicalNight(), calendar: calendar) == "Nuit du 19 au 20 nov.")
    }

    @Test func titleSpansTwoMonths() {
        var night = NightFixtures.typicalNight()
        night.day = NightFixtures.date(2026, 11, 1)
        #expect(NightText.title(night, calendar: calendar) == "Nuit du 31 oct. au 1 nov.")
    }

    @Test func timesSayOneOrSeveralAwakenings() {
        #expect(NightText.times(NightFixtures.typicalNight(awakenings: 1), calendar: calendar)
            == "Endormi à 23:10 · Réveillé à 06:50 · 1 réveil")
        #expect(NightText.times(NightFixtures.typicalNight(awakenings: 2), calendar: calendar).hasSuffix("· 2 réveils"))
        #expect(NightText.times(NightFixtures.typicalNight(awakenings: 0), calendar: calendar).hasSuffix("· aucun réveil"))
    }

    @Test func breakdownSharesAddUpToOne() {
        let detail = NightDetail(night: NightFixtures.typicalNight(unspecified: 15), averages: nil)
        let rows = NightText.breakdownRows(detail)
        #expect(rows.map(\.stage) == [.deep, .core, .rem, .awake, .asleepUnspecified])
        #expect(abs(rows.reduce(0) { $0 + $1.share } - 1) < 1e-9)
        #expect(rows.allSatisfy { $0.delta == nil })
    }

    @Test func breakdownNamesTheUnstagedRestSansPhase() {
        let rows = NightText.breakdownRows(NightDetail(night: NightFixtures.typicalNight(unspecified: 15), averages: nil))
        #expect(rows.map(\.name) == ["Profond", "Léger", "Paradoxal", "Éveil", "Sans phase"])
    }

    @Test func hypnogramGivesTheUnstagedRestItsOwnRow() {
        var night = NightFixtures.typicalNight(unspecified: 60)
        night.segments = [SleepSegment(start: NightFixtures.date(2026, 11, 20, 5, 50), end: NightFixtures.date(2026, 11, 20, 6, 50),
                                       stage: .asleepUnspecified)]
        #expect(NightText.hypnogramRows(night) == [.awake, .rem, .core, .deep, .asleepUnspecified])
        #expect(NightText.stageName(.asleepUnspecified, hasStages: true) == "Sans phase")
    }

    @Test func hypnogramRowsWithoutUnstagedRest() {
        var night = NightFixtures.typicalNight()
        night.segments = [SleepSegment(start: NightFixtures.date(2026, 11, 20, 1), end: NightFixtures.date(2026, 11, 20, 2),
                                       stage: .deep)]
        #expect(NightText.hypnogramRows(night) == [.awake, .rem, .core, .deep])
    }

    @Test func hypnogramWithoutStagesHasAwakeAndAsleep() {
        let night = NightFixtures.typicalNight(hasStages: false)
        #expect(NightText.hypnogramRows(night) == [.awake, .asleepUnspecified])
        #expect(NightText.stageName(.asleepUnspecified, hasStages: false) == "Endormi")
    }

    @Test func breakdownHidesUnstagedRowWhenEmpty() {
        let rows = NightText.breakdownRows(NightDetail(night: NightFixtures.typicalNight(), averages: nil))
        #expect(rows.map(\.stage) == [.deep, .core, .rem, .awake])
    }

    @Test func barIsHiddenAtZeroMinutes() {
        let empty = BreakdownRow(stage: .awake, minutes: 0, share: 0, delta: nil)
        #expect(empty.barWidth(available: 300, minimum: 8) == 0)
    }

    @Test func barKeepsAMinimumWidthWhenPresent() {
        let tiny = BreakdownRow(stage: .awake, minutes: 1, share: 0.002, delta: nil)
        #expect(tiny.barWidth(available: 300, minimum: 8) == 8)
        let half = BreakdownRow(stage: .core, minutes: 225, share: 0.5, delta: nil)
        #expect(half.barWidth(available: 300, minimum: 8) == 150)
        #expect(tiny.barWidth(available: 4, minimum: 8) == 4)
    }

    @Test func breakdownIsEmptyWithoutStages() {
        #expect(NightText.breakdownRows(NightDetail(night: NightFixtures.typicalNight(hasStages: false), averages: nil)).isEmpty)
    }

    @Test func breakdownComparesWithTheAverage() {
        let averages = StageAverages(deep: 78, core: 300.2, rem: 66, awake: 10, nights: 14)
        let rows = NightText.breakdownRows(NightDetail(night: NightFixtures.typicalNight(), averages: averages))
        #expect(rows.map(\.delta) == ["+12 min", nil, "\u{2212}6 min", nil])
    }

    @Test func deltaIsHiddenWhenRoundedToZero() {
        #expect(NightText.delta(minutes: 90, average: 90.4) == nil)
        #expect(NightText.delta(minutes: 90, average: nil) == nil)
        #expect(NightText.delta(minutes: 90, average: 80) == "+10 min")
    }

    @Test func otherBlockGivesItsSpanAndMinutes() {
        let block = SleepBlock(start: NightFixtures.date(2026, 11, 19, 18, 5), end: NightFixtures.date(2026, 11, 19, 18, 30),
                               asleepMinutes: 25)
        #expect(NightText.otherBlock(block, calendar: calendar) == "Aussi compté : 18:05–18:30, 25 min")
    }

    @Test func spokenSummaryNamesTimesAndStages() {
        let spoken = NightText.spokenSummary(NightFixtures.typicalNight(), calendar: calendar)
        #expect(spoken.hasPrefix("Endormi à 23 heures 10, réveillé à 6 heures 50, 1 réveil"))
        #expect(spoken.contains("1 heure 30 minutes de profond"))
    }

    @Test func spokenSummaryWithoutStagesSaysSo() {
        let spoken = NightText.spokenSummary(NightFixtures.typicalNight(hasStages: false), calendar: calendar)
        #expect(spoken.contains("phases non fournies"))
        #expect(!spoken.contains("profond"))
    }
}
