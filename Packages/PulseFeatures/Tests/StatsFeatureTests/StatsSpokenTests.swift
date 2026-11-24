import Accessibility
import Foundation
import PulseContent
import PulseDomain
import PulseServices
@testable import StatsFeature
import Testing

/// Les textes dits de l'onglet Stats : records, assiduité, résumés et valeurs des graphiques. Jamais « kg », « ms », « bpm »,
/// « reps », « 1RM » ni un mois abrégé.
private enum Spoken {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: year, month: month, day: day, hour: 12).date ?? .distantPast
    }

    static let today = date(11, 20)
    static let window = StatsWindow(period: .month, now: today, calendar: calendar)
}

// MARK: - Records

struct StatsRecordSpokenTests {
    @Test func raceTimesAreSpokenAsDurations() {
        #expect(StatsText.raceTimeSpoken(seconds: 1_471) == "24 minutes 31")
        #expect(StatsText.raceTimeSpoken(seconds: 6_307) == "1 heure 45 minutes 7")
        #expect(StatsText.raceTimeSpoken(seconds: 1_200) == "20 minutes")
        #expect(StatsText.raceTimeSpoken(seconds: .infinity) == "\u{2014}")
    }

    private func line(kind: RecordKind = .estimatedOneRepMax, value: Double = 96, weight: Double? = 85, reps: Int? = 5,
                      gain: Double? = 2.5, isNew: Bool = true, date: Date = Spoken.date(10, 28)) -> StrengthRecordLine {
        StrengthRecordLine(exercise: .content(id: "back-squat-barbell"), name: "Squat", kind: kind, value: value, weightKg: weight,
                           reps: reps, date: date, gain: gain, isNew: isNew)
    }

    @Test func strengthRecordGivesTheValueFirstAndSpellsEverythingOut() {
        let text = StatsText.strengthRecordSpoken(line(), calendar: Spoken.calendar, today: Spoken.today)
        #expect(text == "Squat : 96 kilos, maximum estimé sur une répétition, série de 85 kilos pour 5 répétitions, "
            + "le 28 octobre, plus 2,5 kilos.")
    }

    @Test func strengthRecordWithoutGainOrSet() {
        let fresh = line(weight: nil, reps: nil, gain: nil, isNew: true)
        #expect(StatsText.strengthRecordSpoken(fresh, calendar: Spoken.calendar, today: Spoken.today)
            == "Squat : 96 kilos, maximum estimé sur une répétition, le 28 octobre, nouveau.")
        let old = line(weight: nil, reps: nil, gain: nil, isNew: false, date: Spoken.date(3, 2, year: 2025))
        #expect(StatsText.strengthRecordSpoken(old, calendar: Spoken.calendar, today: Spoken.today)
            == "Squat : 96 kilos, maximum estimé sur une répétition, le 2 mars 2025.")
    }

    @Test func repetitionRecordsUseRepetitionsAndSingularKilo() {
        let record = line(kind: .repsAtWeight, value: 14, weight: 1, reps: 14, gain: 1)
        let text = StatsText.strengthRecordSpoken(record, calendar: Spoken.calendar, today: Spoken.today)
        #expect(text == "Squat : 14 répétitions, série de 1 kilo pour 14 répétitions, le 28 octobre, plus 1 répétition.")
    }

    @Test func spokenRecordsNeverUseAbbreviations() {
        let text = StatsText.strengthRecordSpoken(line(), calendar: Spoken.calendar, today: Spoken.today)
        for forbidden in ["kg", "reps", "1RM", "oct.", "×", "·"] { #expect(!text.contains(forbidden), "\(forbidden)") }
    }

    @Test func runRecordSpeaksDistanceTimeAndOrigin() {
        let run = RunBest(distance: .fiveK, seconds: 1_471, date: Spoken.date(9, 14), isNew: true)
        #expect(StatsText.runRecordSpoken(run, calendar: Spoken.calendar, today: Spoken.today)
            == "5 kilomètres : 24 minutes 31, nouveau, allure moyenne de la sortie du 14 septembre.")
        let half = RunBest(distance: .half, seconds: 6_307, date: Spoken.date(9, 14), isNew: false)
        #expect(StatsText.runRecordSpoken(half, calendar: Spoken.calendar, today: Spoken.today)
            == "Semi-marathon : 1 heure 45 minutes 7, allure moyenne de la sortie du 14 septembre.")
        let none = RunBest(distance: .tenK, seconds: nil, date: nil, isNew: false)
        #expect(StatsText.runRecordSpoken(none, calendar: Spoken.calendar, today: Spoken.today)
            == "10 kilomètres : pas encore couru.")
    }
}

// MARK: - Assiduité

struct StatsAttendanceSpokenTests {
    /// Une semaine du lundi 2 au dimanche 8 novembre, entraînée lundi, mercredi, vendredi et samedi.
    private func week(levels: [Int], start: Date = Spoken.date(11, 2)) -> [AttendanceDay] {
        levels.enumerated().map { offset, level in
            AttendanceDay(date: Spoken.calendar.date(byAdding: .day, value: offset, to: start) ?? start, level: level,
                          isFuture: false)
        }
    }

    @Test func columnValueListsTheTrainedDays() {
        let trained = week(levels: [2, 0, 1, 0, 3, 4, 0])
        #expect(StatsText.attendanceDays(week: trained, calendar: Spoken.calendar)
            == "4 jours d'entraînement : lundi, mercredi, vendredi, samedi")
        let single = week(levels: [0, 0, 0, 1, 0, 0, 0])
        #expect(StatsText.attendanceDays(week: single, calendar: Spoken.calendar) == "1 jour d'entraînement : jeudi")
        let empty = week(levels: [0, 0, 0, 0, 0, 0, 0])
        #expect(StatsText.attendanceDays(week: empty, calendar: Spoken.calendar) == "aucun jour d'entraînement")
    }

    @Test func columnLabelNamesTheWeek() {
        let days = week(levels: [1, 0, 0, 0, 0, 0, 0])
        #expect(StatsText.attendanceWeekLabel(week: days, isCurrent: false, calendar: Spoken.calendar) == "Semaine du 2 novembre")
        #expect(StatsText.attendanceWeekLabel(week: days, isCurrent: true, calendar: Spoken.calendar)
            == "Semaine en cours, du 2 novembre")
    }

    @Test func futureDaysAreNotCounted() {
        let days = [AttendanceDay(date: Spoken.date(11, 17), level: 1, isFuture: false),
                    AttendanceDay(date: Spoken.date(11, 18), level: 0, isFuture: true)]
        #expect(StatsText.attendanceDays(week: days, calendar: Spoken.calendar) == "1 jour d'entraînement : mardi")
    }
}

// MARK: - Résumés

struct StatsChartSummaryTests {
    @Test func ratioSummary() {
        let points = [0.86, 1.0, 1.12, 1.31, 1.12].enumerated().map {
            StatsPoint(date: Spoken.date(11, 10 + $0.offset), value: $0.element)
        }
        #expect(StatsText.ratioSummary(points: points, period: .month)
            == "Ratio aigu sur chronique, 30 jours : dernier 1,12, de 0,86 à 1,31. Zone optimale de 0,8 à 1,3, risque à 1,5.")
    }

    @Test func loadSummary() {
        let totals = LoadTotals(tonnageKg: 0, runMeters: 0, rideMeters: 0, minutes: 0, sessions: 3, strengthShare: nil,
                                strengthLoad: 5_200, runLoad: 2_650, rideLoad: 600)
        #expect(StatsText.loadSummary(totals: totals, period: .month)
            == "Charge, 30 jours : 8\u{202F}450 en tout, dont musculation 5\u{202F}200, course 2\u{202F}650, vélo 600.")
    }

    @Test func baselineSummariesSpeakTheirUnit() {
        let points = [BaselinePoint(date: Spoken.date(11, 10), value: 42, baseline: 54),
                      BaselinePoint(date: Spoken.date(11, 11), value: 70, baseline: 54)]
        #expect(StatsText.baselineSummary(measure: .hrv, points: points, period: .month)
            == "Variabilité et ligne de base, 30 jours : moyenne 56 millisecondes, de 42 à 70 millisecondes, "
            + "ligne de base 54 millisecondes.")
        let resting = [BaselinePoint(date: Spoken.date(11, 10), value: 58, baseline: nil),
                       BaselinePoint(date: Spoken.date(11, 11), value: 60, baseline: nil)]
        #expect(StatsText.baselineSummary(measure: .restingHeartRate, points: resting, period: .week)
            == "Fréquence cardiaque au repos, 7 jours : moyenne 59 battements par minute, de 58 à 60 battements par minute.")
    }

    @Test func sleepSummaryNamesTheShortestAndLongestNights() {
        let points = [SleepPoint(date: Spoken.date(11, 3), asleepMinutes: 330, deepMinutes: 60),
                      SleepPoint(date: Spoken.date(11, 4), asleepMinutes: 432, deepMinutes: 90),
                      SleepPoint(date: Spoken.date(11, 5), asleepMinutes: 540, deepMinutes: nil)]
        #expect(StatsText.sleepSummary(points: points, deepShare: 0.19, period: .month, bucket: .day, calendar: Spoken.calendar)
            == "Sommeil, 30 jours : 7 heures 14 minutes en moyenne, profond 19 %, nuit la plus courte 5 heures 30 minutes le 3 novembre, "
            + "nuit la plus longue 9 heures le 5 novembre.")
        #expect(StatsText.sleepSummary(points: points, deepShare: nil, period: .year, bucket: .week, calendar: Spoken.calendar)
            == "Sommeil, 1 an : 7 heures 14 minutes en moyenne, semaine la plus courte 5 heures 30 minutes la semaine du 3 novembre, "
            + "semaine la plus longue 9 heures la semaine du 5 novembre.")
    }

    @Test func categoriesSummarySpeaksDays() {
        let counts = [CategoryCount(category: .optimal, days: 6), CategoryCount(category: .normal, days: 18),
                      CategoryCount(category: .moderateFatigue, days: 5), CategoryCount(category: .overreached, days: 1)]
        #expect(StatsText.categoriesSummary(counts, period: .month)
            == "Journées par état de forme, 30 jours : Forme optimale 6 jours, Forme normale 18 jours, "
            + "Fatigue modérée 5 jours, Surmenage 1 jour.")
    }

    @Test func muscleMapSummaryNamesTheTopMuscles() {
        let top = [MuscleLoad(muscle: .chest, sets: 14), MuscleLoad(muscle: .quads, sets: 1), MuscleLoad(muscle: .lats, sets: 11.5),
                   MuscleLoad(muscle: .abs, sets: 3)]
        #expect(StatsText.mapSummary(top: top, period: .month)
            == "Muscles travaillés, 30 jours : pectoraux 14 séries, quadriceps 1 série, grands dorsaux 11,5 séries.")
        #expect(StatsText.setsText(0.5) == "0,5 série")
    }

    @Test func balanceIsSpokenWithItsVerdict() {
        #expect(StatsText.balanceSpoken(title: "Pousser et tirer", first: 18, second: 9, isUnbalanced: true, emptyReason: "")
            == "Pousser et tirer : 18 séries contre 9, ratio 2, déséquilibré.")
        #expect(StatsText.balanceSpoken(title: "Pousser et tirer", first: 12, second: 12, isUnbalanced: false, emptyReason: "")
            == "Pousser et tirer : 12 séries contre 12, ratio 1, équilibré.")
        #expect(StatsText.balanceSpoken(title: "Pousser et tirer", first: 0, second: 0, isUnbalanced: false,
                                        emptyReason: "aucune série")
            == "Pousser et tirer : Pas assez de données, aucune série.")
    }

    @Test func balanceRatioRoundsOutwardNearTheBounds() {
        #expect(StatsText.balanceRatioText(first: 2, second: 3, firstMissing: "a", secondMissing: "b") == "ratio 0,66")
        #expect(StatsText.balanceRatioText(first: 0, second: 4, firstMissing: "sans poussée", secondMissing: "b")
            == "sans poussée")
        #expect(StatsText.balanceRatioText(first: 4, second: 0, firstMissing: "a", secondMissing: "sans tirage") == "sans tirage")
    }

    @Test func tilesAreSpokenFromTheirSpokenParts() {
        let plain = StatsTileContent(title: "Séances", value: "12", details: ["sur 30 jours"], emptyReason: "rien")
        #expect(StatsText.tileSpoken(plain) == "Séances, 12, sur 30 jours")
        let spoken = StatsTileContent(title: "FC au repos", value: "58 bpm", details: ["+6 % vs 30 j précédents"],
                                      emptyReason: "rien", spokenTitle: "Fréquence cardiaque au repos",
                                      spokenValue: "58 battements par minute",
                                      spokenDetails: ["plus 6 % par rapport aux 30 jours précédents"])
        #expect(StatsText.tileSpoken(spoken)
            == "Fréquence cardiaque au repos, 58 battements par minute, plus 6 % par rapport aux 30 jours précédents")
        let empty = StatsTileContent(title: "Séances", value: nil, emptyReason: "aucune séance")
        #expect(StatsText.tileSpoken(empty) == "Séances, Pas assez de données, aucune séance")
    }

    @Test func nightAxisFollowsTheBucket() {
        #expect(StatsText.nightAxisName(.day) == "Nuit" && StatsText.nightAxisName(.week) == "Semaine")
    }

    @Test func comparisonIsSpokenInFull() {
        #expect(StatsText.comparisonSpoken(StatsComparison(value: 106, previous: 100), days: 30)
            == "+6 % par rapport aux 30 jours précédents")
        #expect(StatsText.comparisonSpoken(nil, days: 30) == nil)
        #expect(StatsText.comparisonSpoken(StatsComparison(value: 106, previous: 100), days: 365)
            == "+6 % par rapport à l'année précédente")
    }

    @Test func tileComparisonIsWrittenAsItIsSpoken() {
        let comparison = StatsComparison(value: 106, previous: 100)
        #expect(StatsWindow(period: .month, now: Spoken.today, calendar: Spoken.calendar).comparisonText(comparison)
            == "+6 % par rapport aux 30 jours précédents")
        #expect(StatsWindow(period: .year, now: Spoken.today, calendar: Spoken.calendar).comparisonText(comparison)
            == "+6 % par rapport à l'année précédente")
    }

    @Test func ratioWaitingTextSaysHistory() {
        #expect(LoadSection.ratioWaitingText(days: 1)
            == "Le ratio aigu / chronique s'affiche après 28 jours d'historique (encore 1 jour)")
        #expect(LoadSection.ratioWaitingText(days: 12)
            == "Le ratio aigu / chronique s'affiche après 28 jours d'historique (encore 12 jours)")
    }
}

// MARK: - Valeurs des marques

struct StatsMarkSpokenTests {
    @Test func ratioPoint() {
        let spoken = StatsText.ratioPointSpoken(StatsPoint(date: Spoken.date(11, 12), value: 1.123), calendar: Spoken.calendar)
        #expect(spoken.label == "12 novembre" && spoken.value == "1,12")
    }

    @Test func loadBarNamesTheDisciplineAndTheBucket() {
        let day = StatsText.loadBarSpoken(start: Spoken.date(11, 3), discipline: "Course", value: 2_650, bucket: .day,
                                          calendar: Spoken.calendar)
        #expect(day.label == "3 novembre, Course" && day.value == "2\u{202F}650")
        let week = StatsText.loadBarSpoken(start: Spoken.date(11, 3), discipline: "Vélo", value: 600, bucket: .week,
                                           calendar: Spoken.calendar)
        #expect(week.label == "Semaine du 3 novembre, Vélo" && week.value == "600")
    }

    @Test func baselinePointSpeaksItsUnit() {
        let point = BaselinePoint(date: Spoken.date(11, 12), value: 56, baseline: 54)
        let night = StatsText.baselinePointSpoken(measure: .hrv, point: point, bucket: .day, calendar: Spoken.calendar)
        #expect(night.label == "Nuit du 12 novembre" && night.value == "56 millisecondes, ligne de base 54 millisecondes")
        let week = StatsText.baselinePointSpoken(measure: .restingHeartRate,
                                                 point: BaselinePoint(date: Spoken.date(11, 9), value: 1, baseline: nil),
                                                 bucket: .week, calendar: Spoken.calendar)
        #expect(week.label == "Semaine du 9 novembre" && week.value == "1 battement par minute")
    }

    @Test func sleepPointSpeaksTotalAndDeep() {
        let point = SleepPoint(date: Spoken.date(11, 12), asleepMinutes: 432, deepMinutes: 80)
        let spoken = StatsText.sleepPointSpoken(point: point, bucket: .day, calendar: Spoken.calendar)
        #expect(spoken.label == "Nuit du 12 novembre" && spoken.value == "7 heures 12 minutes, dont 1 heure 20 minutes de sommeil profond")
        let light = StatsText.sleepPointSpoken(point: SleepPoint(date: Spoken.date(11, 12), asleepMinutes: 420, deepMinutes: nil),
                                               bucket: .day, calendar: Spoken.calendar)
        #expect(light.value == "7 heures")
    }

    @Test func sleepPointSpokenListsStages() {
        let point = SleepPoint(date: Spoken.date(11, 12), asleepMinutes: 450, deepMinutes: 90, coreMinutes: 270, remMinutes: 90,
                               unspecifiedMinutes: 0)
        let spoken = StatsText.sleepPointSpoken(point: point, bucket: .day, calendar: Spoken.calendar)
        #expect(spoken.value
            == "7 heures 30 minutes, dont 1 heure 30 minutes de profond, 4 heures 30 minutes de léger, 1 heure 30 minutes de paradoxal")
    }

    @Test func categoryPoint() {
        let spoken = StatsText.categorySpoken(CategoryCount(category: .overreached, days: 1))
        #expect(spoken.label == "Surmenage" && spoken.value == "1 jour")
    }
}

// MARK: - Descripteurs de graphique

struct StatsChartDescriptorTests {
    private let window = Spoken.window

    @Test func ratioDescriptor() throws {
        let points = [0.9, 1.1, 1.3].enumerated().map { StatsPoint(date: Spoken.date(11, 10 + $0.offset), value: $0.element) }
        let built = StatsChartDescriptors.ratio(points: points, window: window).makeChartDescriptor()
        #expect(built.title == "Ratio aigu sur chronique")
        #expect(built.summary == StatsText.ratioSummary(points: points, period: .month))
        #expect(built.series.map(\.name) == ["Ratio"] && built.series[0].dataPoints.count == 3)
        #expect(built.yAxis?.range == 0...2)
        #expect(built.yAxis?.valueDescriptionProvider(1.25) == "1,25")
    }

    @Test func ratioDescriptorTopFollowsHighValues() {
        let points = [StatsPoint(date: Spoken.date(11, 10), value: 2.5), StatsPoint(date: Spoken.date(11, 11), value: 1)]
        let built = StatsChartDescriptors.ratio(points: points, window: window).makeChartDescriptor()
        #expect(built.yAxis?.range == 0...(2.5 * 1.1))
        #expect(StatsChartDescriptors.ratioTop(points) == 2.5 * 1.1)
    }

    @Test func loadDescriptorHasOneSeriePerDiscipline() {
        let bars = [LoadBar(start: Spoken.date(11, 3), strength: 100, run: 50, ride: 0),
                    LoadBar(start: Spoken.date(11, 10), strength: 120, run: 0, ride: 30)]
        let totals = LoadTotals(tonnageKg: 0, runMeters: 0, rideMeters: 0, minutes: 0, sessions: 2, strengthShare: nil,
                                strengthLoad: 220, runLoad: 50, rideLoad: 30)
        let built = StatsChartDescriptors.load(bars: bars, totals: totals, window: window).makeChartDescriptor()
        #expect(built.series.map(\.name) == ["Musculation", "Course", "Vélo"])
        #expect(built.series.allSatisfy { $0.dataPoints.count == 2 })
        #expect(built.yAxis?.range == 0...120)
        #expect(built.summary == StatsText.loadSummary(totals: totals, period: .month))
    }

    @Test func baselineDescriptorDropsMissingBaselines() {
        let points = [BaselinePoint(date: Spoken.date(11, 10), value: 42, baseline: 54),
                      BaselinePoint(date: Spoken.date(11, 11), value: 70, baseline: nil)]
        let built = StatsChartDescriptors.baseline(measure: .hrv, points: points, window: window).makeChartDescriptor()
        #expect(built.series.map(\.name) == ["Mesure", "Ligne de base"])
        #expect(built.series[0].dataPoints.count == 2 && built.series[1].dataPoints.count == 1)
        #expect(built.yAxis?.valueDescriptionProvider(56) == "56 millisecondes")
        #expect(built.yAxis?.title == "Variabilité, en millisecondes")
        let resting = StatsChartDescriptors.baseline(measure: .restingHeartRate, points: points, window: window)
            .makeChartDescriptor()
        #expect(resting.yAxis?.valueDescriptionProvider(1) == "1 battement par minute")
    }

    @Test func sleepDescriptorSpeaksHoursAsDurations() {
        let points = [SleepPoint(date: Spoken.date(11, 3), asleepMinutes: 450, deepMinutes: 90),
                      SleepPoint(date: Spoken.date(11, 4), asleepMinutes: 420, deepMinutes: nil)]
        let built = StatsChartDescriptors.sleep(points: points, deepShare: 0.2, window: window).makeChartDescriptor()
        #expect(built.series.map(\.name) == ["Sommeil total", "Sommeil profond"])
        #expect(built.series[0].dataPoints.count == 2 && built.series[1].dataPoints.count == 1)
        #expect(built.yAxis?.valueDescriptionProvider(7.5) == "7 heures 30 minutes")
        #expect(built.yAxis?.valueDescriptionProvider(1) == "1 heure")
    }

    @Test func categoriesDescriptorIsCategorical() {
        let counts = [CategoryCount(category: .optimal, days: 6), CategoryCount(category: .normal, days: 1)]
        let built = StatsChartDescriptors.categories(counts, window: window).makeChartDescriptor()
        let axis = built.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(axis?.categoryOrder == ["Forme optimale", "Forme normale"])
        #expect(built.series.count == 1 && built.series[0].dataPoints.count == 2)
        #expect(built.yAxis?.valueDescriptionProvider(1) == "1 jour" && built.yAxis?.valueDescriptionProvider(6) == "6 jours")
        #expect(built.summary == StatsText.categoriesSummary(counts, period: .month))
    }
}
