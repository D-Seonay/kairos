import Foundation
import PulseServices
@testable import StatsFeature
import Testing

/// La lecture au doigt des graphiques des Stats : la marque la plus proche d'une date, puis les textes de l'annotation.
struct StatsChartReadingTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// Minuit (ou l'heure donnée) d'un jour de novembre 2026, à Paris.
    private static func day(_ day: Int, month: Int = 11, hour: Int = 0) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: month, day: day, hour: hour).date
            ?? .distantPast
    }

    // MARK: Point le plus proche

    @Test func nearestPicksTheClosestDateWithoutBucket() {
        let points = [10, 12, 15].map { StatsPoint(date: Self.day($0), value: Double($0)) }
        let nearest = { (date: Date) in
            StatsChartReadings.nearest(points, to: date, unit: nil, calendar: Self.calendar, at: \.date)?.value
        }
        #expect(nearest(Self.day(10, hour: 20)) == 10)
        #expect(nearest(Self.day(11, hour: 6)) == 12)
        #expect(nearest(Self.day(1)) == 10, "Avant le premier point, le premier")
        #expect(nearest(Self.day(30)) == 15, "Après le dernier, le dernier")
        #expect(StatsChartReadings.nearest([StatsPoint](), to: Self.day(1), unit: nil, calendar: Self.calendar, at: \.date) == nil)
    }

    @Test func nearestUsesTheMiddleOfEachBucket() {
        // Barres de semaine (lundis 2, 9 et 16 novembre) : le dimanche 15 au soir tombe dans la barre du 9.
        let bars = [2, 9, 16].map { LoadBar(start: Self.day($0), strength: Double($0), run: 0, ride: 0) }
        let nearest = { (date: Date) in
            StatsChartReadings.nearest(bars, to: date, unit: .weekOfYear, calendar: Self.calendar, at: \.start)?.strength
        }
        #expect(nearest(Self.day(15, hour: 20)) == 9)
        #expect(nearest(Self.day(16, hour: 6)) == 16)
        #expect(StatsChartReadings.anchor(Self.day(12), unit: .day, calendar: Self.calendar) == Self.day(12, hour: 12))
        #expect(StatsChartReadings.anchor(Self.day(12), unit: nil, calendar: Self.calendar) == Self.day(12))
    }

    // MARK: Textes de l'annotation

    @Test func ratioReadingShowsTheDayAndTheRatio() throws {
        let points = [StatsPoint(date: Self.day(11), value: 0.9), StatsPoint(date: Self.day(12), value: 1.123)]
        let reading = try #require(StatsChartReadings.ratio(points, at: Self.day(12, hour: 3), calendar: Self.calendar))
        #expect(reading.date == Self.day(12))
        #expect(reading.title == "12 nov.")
        #expect(reading.lines == ["Ratio 1,12"])
        #expect(reading.spoken == "12 novembre, 1,12")
    }

    @Test func loadReadingListsTheLoadedDisciplines() throws {
        let bars = [LoadBar(start: Self.day(9), strength: 2_140, run: 650, ride: 0),
                    LoadBar(start: Self.day(16), strength: 0, run: 0, ride: 0)]
        let week = try #require(StatsChartReadings.load(bars, at: Self.day(11), bucket: .week, calendar: Self.calendar))
        #expect(week.title == "Semaine du 9 nov.")
        #expect(week.lines == ["Musculation 2\u{202F}140", "Course 650"])
        #expect(week.spoken == "Semaine du 9 novembre, Musculation 2\u{202F}140, Course 650")
        #expect(week.date > Self.day(12) && week.date < Self.day(14), "La règle tombe au milieu de la semaine")
        let empty = try #require(StatsChartReadings.load(bars, at: Self.day(18), bucket: .week, calendar: Self.calendar))
        #expect(empty.lines == ["Aucune charge"])
        let daily = try #require(StatsChartReadings.load(bars, at: Self.day(9, hour: 10), bucket: .day, calendar: Self.calendar))
        #expect(daily.title == "9 nov." && daily.date == Self.day(9, hour: 12))
    }

    @Test func baselineReadingGivesTheValueAndItsBaselineWithUnits() throws {
        let points = [BaselinePoint(date: Self.day(12), value: 56.4, baseline: 54),
                      BaselinePoint(date: Self.day(13), value: 51, baseline: nil)]
        let hrv = try #require(StatsChartReadings.baseline(points, measure: .hrv, at: Self.day(12, hour: 14), bucket: .day,
                                                           calendar: Self.calendar))
        #expect(hrv.title == "Nuit du 12 nov.")
        #expect(hrv.lines == ["56 ms", "Ligne de base 54 ms"])
        #expect(hrv.spoken == "Nuit du 12 novembre, 56 millisecondes, ligne de base 54 millisecondes")
        let resting = try #require(StatsChartReadings.baseline(points, measure: .restingHeartRate, at: Self.day(13, hour: 12),
                                                               bucket: .day, calendar: Self.calendar))
        #expect(resting.lines == ["51 bpm"])
    }

    @Test func sleepReadingGivesTheTotalThenEachStage() throws {
        let staged = SleepPoint(date: Self.day(12), asleepMinutes: 450, deepMinutes: 90, coreMinutes: 270, remMinutes: 90,
                                unspecifiedMinutes: 0)
        let reading = try #require(StatsChartReadings.sleep([staged], at: Self.day(12), bucket: .day, calendar: Self.calendar))
        #expect(reading.title == "Nuit du 12 nov.")
        #expect(reading.lines == ["7 h 30", "Profond 1 h 30", "Léger 4 h 30", "Paradoxal 1 h 30"])
        #expect(reading.spoken.hasPrefix("Nuit du 12 novembre, 7 heures 30 minutes"))

        let old = SleepPoint(date: Self.day(9), asleepMinutes: 432, deepMinutes: 80)
        let week = try #require(StatsChartReadings.sleep([old], at: Self.day(10), bucket: .week, calendar: Self.calendar))
        #expect(week.title == "Semaine du 9 nov.")
        #expect(week.lines == ["7 h 12", "Profond 1 h 20"])
    }
}
