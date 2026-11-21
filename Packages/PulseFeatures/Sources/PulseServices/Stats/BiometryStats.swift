import Foundation
import PulseDomain

/// Un point de courbe avec sa ligne de base : la VFC ou la FC repos d'une nuit (ou d'une semaine sur un an).
public struct BaselinePoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var value: Double
    public var baseline: Double?

    public var id: Date { date }

    public init(date: Date, value: Double, baseline: Double?) {
        self.date = date
        self.value = value
        self.baseline = baseline
    }
}

/// Une barre de sommeil : minutes dormies, dont la part de sommeil profond quand elle est connue.
public struct SleepPoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var asleepMinutes: Double
    public var deepMinutes: Double?

    public var id: Date { date }

    public init(date: Date, asleepMinutes: Double, deepMinutes: Double?) {
        self.date = date
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
    }
}

/// Le nombre de journées d'une catégorie de forme sur la période.
public struct CategoryCount: Sendable, Equatable, Identifiable {
    public var category: RecoveryCategory
    public var days: Int

    public var id: RecoveryCategory { category }

    public init(category: RecoveryCategory, days: Int) {
        self.category = category
        self.days = days
    }
}

/// La vue Biométrie : tendances de VFC, FC repos et sommeil, score moyen et journées par état de forme (spec M7 §7).
public struct BiometryStats: Sendable, Equatable {
    public var hrv: StatsComparison?
    public var restingHeartRate: StatsComparison?
    /// Le sommeil moyen par nuit mesurée, en minutes.
    public var sleepMinutes: StatsComparison?
    /// La part de sommeil profond, de 0 à 1 ; `nil` sans nuit qui connaisse le sommeil et sa part profonde.
    public var deepShare: Double?
    public var score: StatsComparison?
    public var hrvPoints: [BaselinePoint]
    public var restingPoints: [BaselinePoint]
    public var sleepPoints: [SleepPoint]
    /// Toujours les quatre catégories, dans l'ordre de `RecoveryCategory.allCases`.
    public var categories: [CategoryCount]

    /// Les moyennes de VFC, FC et sommeil ignorent les journées estimées par check-in (sans mesure) ; le score et la
    /// répartition les comptent.
    public static func make(recoveries: [DailyRecovery], period: StatsPeriod, now: Date, calendar: Calendar) -> BiometryStats {
        let interval = period.interval(now: now, calendar: calendar)
        let previousInterval = period.previousInterval(now: now, calendar: calendar)
        let rows = dailyRows(recoveries, calendar: calendar)
        let current = rows.filter { interval.start <= $0.day && $0.day < interval.end }
        let previous = rows.filter { previousInterval.start <= $0.day && $0.day < previousInterval.end }
        let measured = current.filter { !$0.recovery.isEstimated }
        let previousMeasured = previous.filter { !$0.recovery.isEstimated }
        let bucket = period.chartBucket

        func comparison(_ value: (DailyRecovery) -> Double?, measuredOnly: Bool = true) -> StatsComparison? {
            let values = (measuredOnly ? measured : current).compactMap { value($0.recovery) }
            let previousValues = (measuredOnly ? previousMeasured : previous).compactMap { value($0.recovery) }
            return average(values).map { StatsComparison(value: $0, previous: average(previousValues)) }
        }

        return BiometryStats(
            hrv: comparison { $0.sdnnMs },
            restingHeartRate: comparison { $0.restingHeartRate },
            sleepMinutes: comparison { $0.asleepMinutes.map(Double.init) },
            deepShare: deepShare(of: measured),
            score: comparison({ $0.score }, measuredOnly: false),
            hrvPoints: baselinePoints(of: measured, bucket: bucket, calendar: calendar, value: { $0.sdnnMs },
                                      baseline: { $0.sdnnBaselineMs }),
            restingPoints: baselinePoints(of: measured, bucket: bucket, calendar: calendar, value: { $0.restingHeartRate },
                                          baseline: { $0.restingHeartRateBaseline }),
            sleepPoints: sleepPoints(of: measured, bucket: bucket, calendar: calendar),
            categories: RecoveryCategory.allCases.map { category in
                CategoryCount(category: category, days: current.filter { $0.recovery.category == category }.count)
            })
    }

    // MARK: - Lignes

    private struct DayRow {
        let day: Date
        let recovery: DailyRecovery
    }

    /// Une ligne par jour de calendrier, la plus récemment mise à jour si deux se partagent le jour, dans l'ordre chronologique.
    private static func dailyRows(_ recoveries: [DailyRecovery], calendar: Calendar) -> [DayRow] {
        var latest: [Date: DailyRecovery] = [:]
        for recovery in recoveries {
            let day = calendar.startOfDay(for: recovery.day)
            if let kept = latest[day], kept.updatedAt >= recovery.updatedAt { continue }
            latest[day] = recovery
        }
        return latest.map { DayRow(day: $0.key, recovery: $0.value) }.sorted { $0.day < $1.day }
    }

    // MARK: - Courbes

    /// Le début du jour, ou du lundi de la semaine, qui contient `date`.
    private static func bucketStart(of date: Date, bucket: StatsBucket, calendar: Calendar) -> Date {
        bucket == .day ? calendar.startOfDay(for: date) : WeekSchedule.weekStart(of: date, calendar: calendar)
    }

    /// Les lignes regroupées par grain, chronologiques : un groupe par nuit sur les périodes courtes, par semaine sur un an.
    private static func grouped(_ rows: [DayRow], bucket: StatsBucket, calendar: Calendar) -> [(start: Date, rows: [DailyRecovery])] {
        Dictionary(grouping: rows) { bucketStart(of: $0.day, bucket: bucket, calendar: calendar) }
            .map { (start: $0.key, rows: $0.value.map(\.recovery)) }
            .sorted { $0.start < $1.start }
    }

    /// Un point par grain qui compte au moins une valeur ; la ligne de base est moyennée sur les nuits qui en ont une.
    private static func baselinePoints(of rows: [DayRow], bucket: StatsBucket, calendar: Calendar, value: (DailyRecovery) -> Double?,
                                       baseline: (DailyRecovery) -> Double?) -> [BaselinePoint] {
        grouped(rows, bucket: bucket, calendar: calendar).compactMap { group in
            average(group.rows.compactMap(value)).map {
                BaselinePoint(date: group.start, value: $0, baseline: average(group.rows.compactMap(baseline)))
            }
        }
    }

    private static func sleepPoints(of rows: [DayRow], bucket: StatsBucket, calendar: Calendar) -> [SleepPoint] {
        grouped(rows, bucket: bucket, calendar: calendar).compactMap { group in
            let deep = average(group.rows.compactMap { $0.deepMinutes.map(Double.init) })
            return average(group.rows.compactMap { $0.asleepMinutes.map(Double.init) }).map {
                SleepPoint(date: group.start, asleepMinutes: $0, deepMinutes: deep)
            }
        }
    }

    // MARK: - Moyennes

    /// La part de profond sur les seules nuits qui connaissent le sommeil et sa part profonde.
    private static func deepShare(of rows: [DayRow]) -> Double? {
        let nights = rows.compactMap { row -> (asleep: Int, deep: Int)? in
            guard let asleep = row.recovery.asleepMinutes, let deep = row.recovery.deepMinutes else { return nil }
            return (asleep, deep)
        }
        let asleep = nights.reduce(0) { $0 + $1.asleep }
        guard asleep > 0 else { return nil }
        return Double(nights.reduce(0) { $0 + $1.deep }) / Double(asleep)
    }

    private static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
