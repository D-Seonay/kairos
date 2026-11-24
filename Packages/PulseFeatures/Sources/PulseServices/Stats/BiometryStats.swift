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

/// Une barre de sommeil : minutes dormies, dont la part de sommeil profond quand elle est connue. Quand au moins une nuit du
/// grain a ses phases, les quatre phases (profond compris) se partagent la hauteur de la barre (spec sommeil §6.5).
public struct SleepPoint: Sendable, Equatable, Identifiable {
    public var date: Date
    public var asleepMinutes: Double
    public var deepMinutes: Double?
    public var coreMinutes: Double?
    public var remMinutes: Double?
    public var unspecifiedMinutes: Double?

    public var id: Date { date }

    /// Vrai si la barre se découpe en phases ; sinon seul le profond est connu (ou rien).
    public var hasStages: Bool { coreMinutes != nil }

    public init(date: Date, asleepMinutes: Double, deepMinutes: Double?, coreMinutes: Double? = nil, remMinutes: Double? = nil,
                unspecifiedMinutes: Double? = nil) {
        self.date = date
        self.asleepMinutes = asleepMinutes
        self.deepMinutes = deepMinutes
        self.coreMinutes = coreMinutes
        self.remMinutes = remMinutes
        self.unspecifiedMinutes = unspecifiedMinutes
    }
}

/// La part de chaque phase dans le sommeil des seules nuits qui ont leurs phases, de 0 à 1 ; les quatre s'additionnent à 1.
public struct StageShares: Sendable, Equatable {
    public var deep: Double
    public var core: Double
    public var rem: Double
    public var unspecified: Double

    public init(deep: Double, core: Double, rem: Double, unspecified: Double) {
        self.deep = deep
        self.core = core
        self.rem = rem
        self.unspecified = unspecified
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
    /// La part de chaque phase sur les seules nuits qui ont leurs phases ; `nil` sans aucune.
    public var stageShares: StageShares?
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
            stageShares: stageShares(of: measured.map(\.recovery)),
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

    /// La hauteur d'une barre est la moyenne d'`asleepMinutes` de toutes les nuits du grain. Si au moins une nuit a ses phases,
    /// leur part (sur ces seules nuits) découpe cette hauteur : les tranches s'additionnent toujours à la barre. Sinon seul le
    /// profond moyen est donné, comme avant les phases.
    private static func sleepPoints(of rows: [DayRow], bucket: StatsBucket, calendar: Calendar) -> [SleepPoint] {
        grouped(rows, bucket: bucket, calendar: calendar).compactMap { group in
            guard let height = average(group.rows.compactMap { $0.asleepMinutes.map(Double.init) }) else { return nil }
            guard let shares = stageShares(of: group.rows) else {
                let deep = average(group.rows.compactMap { $0.deepMinutes.map(Double.init) })
                return SleepPoint(date: group.start, asleepMinutes: height, deepMinutes: deep)
            }
            return SleepPoint(date: group.start, asleepMinutes: height, deepMinutes: shares.deep * height,
                              coreMinutes: shares.core * height, remMinutes: shares.rem * height,
                              unspecifiedMinutes: shares.unspecified * height)
        }
    }

    /// Les parts de phase sur les nuits qui ont leurs phases (et un sommeil non nul), pondérées par leur durée.
    private static func stageShares(of recoveries: [DailyRecovery]) -> StageShares? {
        let staged = recoveries.filter { ($0.asleepMinutes ?? 0) > 0 && $0.coreMinutes != nil }
        func total(_ minutes: KeyPath<DailyRecovery, Int?>) -> Double {
            Double(staged.reduce(0) { $0 + ($1[keyPath: minutes] ?? 0) })
        }
        let asleep = total(\.asleepMinutes)
        guard asleep > 0 else { return nil }
        return StageShares(deep: total(\.deepMinutes) / asleep, core: total(\.coreMinutes) / asleep,
                           rem: total(\.remMinutes) / asleep, unspecified: total(\.unspecifiedMinutes) / asleep)
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
