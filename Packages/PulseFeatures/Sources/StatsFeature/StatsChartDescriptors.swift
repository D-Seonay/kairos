import Foundation
import PulseDesignSystem
import PulseServices

/// Les descripteurs de graphique audio des cinq graphiques de Stats : axes, séries et résumé dits en français. Chacun se pose
/// sur le graphique avec `.accessibilityChartDescriptor(...)`.
enum StatsChartDescriptors {
    /// L'axe vertical de la courbe du ratio : de 0 à 2, plus haut quand un ratio le dépasse (comme le graphique).
    static func ratioTop(_ points: [StatsPoint]) -> Double {
        max(2, (points.map(\.value).max() ?? 0) * 1.1)
    }

    static func ratio(points: [StatsPoint], window: StatsWindow) -> PulseChartDescriptor {
        PulseChartDescriptor(
            title: String(localized: "Ratio aigu sur chronique", bundle: .module),
            summary: StatsText.ratioSummary(points: points, period: window.period),
            xAxis: .dates(title: String(localized: "Jour", bundle: .module)),
            yAxis: .init(title: String(localized: "Ratio", bundle: .module), unit: "", range: 0...ratioTop(points),
                         valueText: { PulseFormat.decimal($0, maxFractionDigits: 2) }),
            series: [.init(name: String(localized: "Ratio", bundle: .module),
                           points: points.map { .init(date: $0.date, y: $0.value) })],
            calendar: window.calendar)
    }

    static func load(bars: [LoadBar], totals: LoadTotals, window: StatsWindow) -> PulseChartDescriptor {
        let top = bars.flatMap { [$0.strength, $0.run, $0.ride] }.max() ?? 0
        func series(_ name: String, _ value: KeyPath<LoadBar, Double>) -> PulseChartDescriptor.Series {
            .init(name: name, points: bars.map { .init(date: $0.start, y: $0[keyPath: value]) })
        }
        return PulseChartDescriptor(
            title: StatsText.loadTitle(window.period.loadBucket),
            summary: StatsText.loadSummary(totals: totals, period: window.period),
            xAxis: .dates(title: String(localized: "Début", bundle: .module)),
            yAxis: .init(title: String(localized: "Charge", bundle: .module), unit: "", range: 0...max(top, 1),
                         valueText: { StatsText.number($0) }),
            series: [series(StatsText.strengthName, \.strength), series(StatsText.runName, \.run),
                     series(StatsText.rideName, \.ride)],
            calendar: window.calendar)
    }

    static func baseline(measure: BiometricMeasure, points: [BaselinePoint], window: StatsWindow) -> PulseChartDescriptor {
        let all = points.map(\.value) + points.compactMap(\.baseline)
        let (low, high) = (all.min() ?? 0, all.max() ?? 0)
        let axisTitle = StatsText.nightAxisName(window.period.chartBucket)
        return PulseChartDescriptor(
            title: measure.spokenName,
            summary: StatsText.baselineSummary(measure: measure, points: points, period: window.period),
            xAxis: .dates(title: axisTitle),
            yAxis: .init(title: measure.axisTitle, unit: "", range: low < high ? low...high : (low - 1)...(high + 1),
                         valueText: { measure.spoken($0) }),
            series: [.init(name: String(localized: "Mesure", bundle: .module),
                           points: points.map { .init(date: $0.date, y: $0.value) }),
                     .init(name: String(localized: "Ligne de base", bundle: .module),
                           points: points.compactMap { point in point.baseline.map { .init(date: point.date, y: $0) } })],
            calendar: window.calendar)
    }

    static func sleep(points: [SleepPoint], deepShare: Double?, window: StatsWindow) -> PulseChartDescriptor {
        let bucket = window.period.chartBucket
        let axisTitle = StatsText.nightAxisName(bucket)
        let top = (points.map(\.asleepMinutes).max() ?? 0) / 60
        return PulseChartDescriptor(
            title: String(localized: "Sommeil", bundle: .module),
            summary: StatsText.sleepSummary(points: points, deepShare: deepShare, period: window.period, bucket: bucket,
                                            calendar: window.calendar),
            xAxis: .dates(title: axisTitle),
            yAxis: .init(title: String(localized: "Sommeil, en heures", bundle: .module), unit: "", range: 0...max(top, 1),
                         valueText: { StatsText.durationSpoken(minutes: $0 * 60) }),
            series: [.init(name: String(localized: "Sommeil total", bundle: .module),
                           points: points.map { .init(date: $0.date, y: $0.asleepMinutes / 60) }),
                     .init(name: String(localized: "Sommeil profond", bundle: .module),
                           points: points.compactMap { point in
                               point.deepMinutes.map { .init(date: point.date, y: min($0, point.asleepMinutes) / 60) }
                           })] + stageSeries(points),
            calendar: window.calendar)
    }

    /// Une série par autre phase présente sur la période (léger, paradoxal, sans phase), seulement pour les barres à phases.
    private static func stageSeries(_ points: [SleepPoint]) -> [PulseChartDescriptor.Series] {
        let stages: [(String, KeyPath<SleepPoint, Double?>)] = [
            (String(localized: "Sommeil léger", bundle: .module), \.coreMinutes),
            (String(localized: "Sommeil paradoxal", bundle: .module), \.remMinutes),
            (String(localized: "Sommeil sans phase", bundle: .module), \.unspecifiedMinutes)
        ]
        return stages.compactMap { name, keyPath in
            let series = points.compactMap { point in
                point[keyPath: keyPath].map { PulseChartDescriptor.Point(date: point.date, y: $0 / 60) }
            }
            return series.contains { $0.y > 0 } ? PulseChartDescriptor.Series(name: name, points: series) : nil
        }
    }

    static func categories(_ categories: [CategoryCount], window: StatsWindow) -> PulseChartDescriptor {
        let top = categories.map(\.days).max() ?? 0
        let names = categories.map { $0.category.localizedName }
        return PulseChartDescriptor(
            title: String(localized: "Journées par état de forme", bundle: .module),
            summary: StatsText.categoriesSummary(categories, period: window.period),
            xAxis: .categories(title: String(localized: "État", bundle: .module), names: names),
            yAxis: .init(title: String(localized: "Jours", bundle: .module), unit: "", range: 0...Double(max(top, 1)),
                         valueText: { StatsText.daysSpoken(Int($0.rounded())) }),
            series: [.init(name: String(localized: "Jours", bundle: .module),
                           points: categories.map { .init(category: $0.category.localizedName, y: Double($0.days)) })],
            calendar: window.calendar)
    }
}
