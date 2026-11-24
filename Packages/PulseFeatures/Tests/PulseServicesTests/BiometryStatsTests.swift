import Foundation
import PulseDomain
import PulseServices
import Testing

struct BiometryStatsTests {
    private let now = TestClock.date("2026-11-20T12:00")
    private var calendar: Calendar { TestClock.calendar }

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)) ?? now
    }

    private func recovery(daysAgo: Int, score: Double = 70, estimated: Bool = false, sdnn: Double? = nil, sdnnBaseline: Double? = nil,
                          resting: Double? = nil, restingBaseline: Double? = nil, asleep: Int? = nil, deep: Int? = nil,
                          updatedAt: Date? = nil) -> DailyRecovery {
        let morning = day(daysAgo).addingTimeInterval(7 * 3_600)
        return DailyRecovery(
            day: morning, score: score, category: RecoveryCategory(score: score), isEstimated: estimated, sdnnMs: sdnn,
            sdnnBaselineMs: sdnnBaseline, restingHeartRate: resting, restingHeartRateBaseline: restingBaseline,
            asleepMinutes: asleep, deepMinutes: deep, calibration: .ready, createdAt: morning, updatedAt: updatedAt ?? morning)
    }

    private func stats(_ recoveries: [DailyRecovery], period: StatsPeriod = .month) -> BiometryStats {
        BiometryStats.make(recoveries: recoveries, period: period, now: now, calendar: calendar)
    }

    @Test func averagesSkipEstimatedDays() {
        let result = stats([
            recovery(daysAgo: 1, sdnn: 50), recovery(daysAgo: 2, sdnn: 60), recovery(daysAgo: 3, sdnn: 70),
            recovery(daysAgo: 4, score: 40, estimated: true)
        ])
        #expect(result.hrv?.value == 60)
        #expect(result.hrvPoints.count == 3)
        // Le jour estimé compte dans la répartition et dans le score, pas dans la VFC.
        #expect(result.categories.first { $0.category == .moderateFatigue }?.days == 1)
        #expect(result.categories.first { $0.category == .normal }?.days == 3)
        #expect(result.score?.value == 62.5)
    }

    @Test func comparesWithPreviousPeriod() throws {
        let result = stats([
            recovery(daysAgo: 1, sdnn: 60), recovery(daysAgo: 2, sdnn: 60),
            recovery(daysAgo: 31, sdnn: 50), recovery(daysAgo: 32, sdnn: 50)
        ])
        #expect(result.hrv?.value == 60)
        #expect(result.hrv?.previous == 50)
        #expect(try abs(#require(result.hrv?.change) - 0.2) < 1e-9)
    }

    @Test func noPreviousDataMeansNoComparison() {
        let result = stats([recovery(daysAgo: 1, sdnn: 60)])
        #expect(result.hrv?.previous == nil)
        #expect(result.hrv?.change == nil)
    }

    @Test func rowsOutsideBothPeriodsAreIgnored() {
        let result = stats([recovery(daysAgo: 1, sdnn: 60), recovery(daysAgo: 70, sdnn: 10), recovery(daysAgo: -1, sdnn: 90)])
        #expect(result.hrv?.value == 60)
        #expect(result.hrv?.previous == nil)
        #expect(result.hrvPoints.count == 1)
    }

    @Test func deepShare() {
        let result = stats([recovery(daysAgo: 1, asleep: 240, deep: 48), recovery(daysAgo: 2, asleep: 180, deep: 36)])
        #expect(result.deepShare == 0.2)
        #expect(result.sleepMinutes?.value == 210)
    }

    @Test func deepShareIgnoresNightsWithoutBothValues() {
        let result = stats([
            recovery(daysAgo: 1, asleep: 400, deep: 80), recovery(daysAgo: 2, asleep: 500), recovery(daysAgo: 3, deep: 99)
        ])
        #expect(result.deepShare == 0.2)
        #expect(result.sleepMinutes?.value == 450)
        #expect(stats([recovery(daysAgo: 1, asleep: 400)]).deepShare == nil)
    }

    @Test func monthGivesOnePointPerMeasuredNightInOrder() {
        let result = stats([
            recovery(daysAgo: 1, sdnn: 55, sdnnBaseline: 52, resting: 50, restingBaseline: 51, asleep: 420, deep: 84),
            recovery(daysAgo: 3, sdnn: 45, resting: 54, asleep: 360),
            recovery(daysAgo: 2, estimated: true)
        ])
        #expect(result.hrvPoints.map(\.date) == [day(3), day(1)])
        #expect(result.hrvPoints.map(\.id) == [day(3), day(1)])
        #expect(result.hrvPoints.map(\.baseline) == [nil, 52])
        #expect(result.restingPoints.map(\.value) == [54, 50])
        #expect(result.sleepPoints == [
            SleepPoint(date: day(3), asleepMinutes: 360, deepMinutes: nil),
            SleepPoint(date: day(1), asleepMinutes: 420, deepMinutes: 84)
        ])
    }

    @Test func yearAveragesPerWeek() {
        // Deux semaines pleines : lundi 2 novembre (il y a 18 jours) et lundi 9 novembre (il y a 11 jours) 2026.
        let firstWeek = (0..<7).map {
            recovery(daysAgo: 18 - $0, sdnn: 40 + Double($0), sdnnBaseline: 50 + Double($0), asleep: 400 + $0, deep: 80)
        }
        let secondWeek = (0..<7).map { recovery(daysAgo: 11 - $0, sdnn: 60 + Double($0), sdnnBaseline: 70, asleep: 500) }
        let result = stats(firstWeek + secondWeek, period: .year)
        #expect(result.hrvPoints.count == 2)
        #expect(result.hrvPoints.map(\.date) == [day(18), day(11)])
        #expect(result.hrvPoints.map(\.value) == [43, 63])
        #expect(result.hrvPoints.map(\.baseline) == [53, 70])
        #expect(result.sleepPoints.map(\.asleepMinutes) == [403, 500])
        #expect(result.sleepPoints.map(\.deepMinutes) == [80, nil])
        // Les tuiles restent calculées sur toutes les nuits.
        #expect(result.hrv?.value == 53)
    }

    /// Une nuit avec phases : profond, léger, paradoxal et sans phase s'additionnent à `asleep`.
    private func staged(daysAgo: Int, asleep: Int, deep: Int, core: Int, rem: Int, unspecified: Int = 0) -> DailyRecovery {
        var night = recovery(daysAgo: daysAgo, asleep: asleep, deep: deep)
        night.coreMinutes = core
        night.remMinutes = rem
        night.unspecifiedMinutes = unspecified
        night.awakeMinutes = 10
        return night
    }

    @Test func sleepPointCarriesStagesWhenNightsHaveThem() throws {
        let result = stats([staged(daysAgo: 1, asleep: 480, deep: 96, core: 288, rem: 96)])
        let point = try #require(result.sleepPoints.first)
        #expect(point.hasStages)
        #expect(point.deepMinutes == 96 && point.coreMinutes == 288 && point.remMinutes == 96 && point.unspecifiedMinutes == 0)
    }

    @Test func mixedWeekScalesStageSharesToTheBarHeight() throws {
        let result = stats([recovery(daysAgo: 1, asleep: 420, deep: 70), staged(daysAgo: 2, asleep: 480, deep: 96, core: 288, rem: 96)],
                           period: .year)
        let point = try #require(result.sleepPoints.first)
        #expect(result.sleepPoints.count == 1)
        #expect(point.asleepMinutes == 450)
        func near(_ value: Double?, _ expected: Double) -> Bool { value.map { abs($0 - expected) < 1e-9 } ?? false }
        #expect(near(point.deepMinutes, 90) && near(point.coreMinutes, 270) && near(point.remMinutes, 90))
        #expect(near(point.unspecifiedMinutes, 0))
        let sum = (point.deepMinutes ?? 0) + (point.coreMinutes ?? 0) + (point.remMinutes ?? 0) + (point.unspecifiedMinutes ?? 0)
        #expect(abs(sum - point.asleepMinutes) < 1e-9)
    }

    @Test func weekWithoutStagedNightsKeepsDeepOnly() throws {
        let result = stats([recovery(daysAgo: 1, asleep: 420, deep: 80), recovery(daysAgo: 2, asleep: 480, deep: 100)], period: .year)
        let point = try #require(result.sleepPoints.first)
        #expect(!point.hasStages)
        #expect(point.deepMinutes == 90 && point.coreMinutes == nil && point.remMinutes == nil)
    }

    @Test func stageSharesIgnoreUnstagedNights() throws {
        let result = stats([recovery(daysAgo: 1, asleep: 300, deep: 100),
                            staged(daysAgo: 2, asleep: 400, deep: 80, core: 240, rem: 60, unspecified: 20)])
        let shares = try #require(result.stageShares)
        #expect(shares.deep == 0.2 && shares.core == 0.6 && shares.rem == 0.15 && shares.unspecified == 0.05)
        #expect(stats([recovery(daysAgo: 1, asleep: 300, deep: 100)]).stageShares == nil)
    }

    @Test func categoriesAlwaysListed() {
        let result = stats([])
        #expect(result.categories == RecoveryCategory.allCases.map { CategoryCount(category: $0, days: 0) })
        #expect(result.categories.map(\.id) == [.optimal, .normal, .moderateFatigue, .overreached])
        #expect(result.hrv == nil)
        #expect(result.restingHeartRate == nil)
        #expect(result.sleepMinutes == nil)
        #expect(result.deepShare == nil)
        #expect(result.score == nil)
        #expect(result.hrvPoints.isEmpty && result.restingPoints.isEmpty && result.sleepPoints.isEmpty)
    }

    @Test func sameDayRowsKeepTheMostRecentlyUpdated() {
        let older = recovery(daysAgo: 1, score: 50, sdnn: 40, updatedAt: now.addingTimeInterval(-3_600))
        let newer = recovery(daysAgo: 1, score: 80, sdnn: 60, updatedAt: now)
        for rows in [[older, newer], [newer, older]] {
            let result = stats(rows)
            #expect(result.hrv?.value == 60)
            #expect(result.score?.value == 80)
            #expect(result.hrvPoints.count == 1)
            #expect(result.categories.reduce(0) { $0 + $1.days } == 1)
        }
    }
}
