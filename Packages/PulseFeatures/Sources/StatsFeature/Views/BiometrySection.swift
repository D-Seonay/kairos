import Charts
import Foundation
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La vue Biométrie (spec M7 §7) : VFC, FC repos, sommeil et score moyens contre la période précédente, puis la VFC face à sa
/// ligne de base, la FC repos, le sommeil par nuit et les journées par état de forme.
struct BiometrySection: View {
    let biometry: BiometryStats
    let window: StatsWindow

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            StatsTileGrid(tiles: tiles)
            BaselineChartCard(title: String(localized: "Variabilité et ligne de base", bundle: .module),
                              points: biometry.hrvPoints, unit: "ms", style: .points, window: window)
            BaselineChartCard(title: String(localized: "FC au repos", bundle: .module),
                              points: biometry.restingPoints, unit: "bpm", style: .line, window: window)
            SleepChartCard(points: biometry.sleepPoints, deepShare: biometry.deepShare, window: window)
            CategoriesCard(categories: biometry.categories, window: window)
        }
    }

    private var tiles: [StatsTileContent] {
        let noNight = String(localized: "aucune nuit mesurée sur la période", bundle: .module)
        var sleepDetails = details(biometry.sleepMinutes)
        if let deep = biometry.deepShare {
            sleepDetails.insert(String(localized: "profond \(PulseFormat.integer(deep * 100, unit: "%"))", bundle: .module), at: 0)
        }
        return [
            StatsTileContent(title: String(localized: "Variabilité moyenne", bundle: .module),
                             value: biometry.hrv.map { PulseFormat.integer($0.value, unit: "ms") },
                             details: details(biometry.hrv), emptyReason: noNight),
            StatsTileContent(title: String(localized: "FC au repos", bundle: .module),
                             value: biometry.restingHeartRate.map { PulseFormat.integer($0.value, unit: "bpm") },
                             details: details(biometry.restingHeartRate), emptyReason: noNight),
            StatsTileContent(title: String(localized: "Sommeil moyen", bundle: .module),
                             value: biometry.sleepMinutes.map { StatsText.duration(minutes: $0.value) },
                             details: sleepDetails, emptyReason: SleepChartCard.emptyReason),
            StatsTileContent(title: String(localized: "Récupération moyenne", bundle: .module),
                             value: biometry.score.map { PulseFormat.integer($0.value, unit: nil) },
                             details: details(biometry.score),
                             emptyReason: String(localized: "aucun score du matin sur la période", bundle: .module))
        ]
    }

    private func details(_ comparison: StatsComparison?) -> [String] {
        window.comparisonText(comparison).map { [$0] } ?? []
    }
}

// MARK: - VFC et FC repos

/// Une valeur par nuit (par semaine sur un an) et sa ligne de base en pointillés. La VFC se lit en points, la FC repos en ligne.
private struct BaselineChartCard: View {
    enum Style {
        case points
        case line
    }

    let title: String
    let points: [BaselinePoint]
    let unit: String
    let style: Style
    let window: StatsWindow

    var body: some View {
        StatsChartCard(title: title) {
            if points.isEmpty {
                StatsEmptyNote(reason: String(localized: "aucune nuit mesurée sur la période", bundle: .module))
            } else {
                chart
                StatsLegend(items: [(String(localized: "Mesure", bundle: .module), StatsInk.full),
                                    (String(localized: "Ligne de base", bundle: .module), StatsInk.medium)])
            }
        }
    }

    private var chart: some View {
        let unit = window.unit(of: window.period.chartBucket)
        let dateLabel = String(localized: "Nuit", bundle: .module)
        return Chart {
            ForEach(points) { point in
                if let baseline = point.baseline {
                    LineMark(x: .value(dateLabel, point.date, unit: unit), y: .value(title, baseline),
                             series: .value("Série", "baseline"))
                        .foregroundStyle(StatsInk.medium)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                switch style {
                case .points:
                    PointMark(x: .value(dateLabel, point.date, unit: unit), y: .value(title, point.value))
                        .foregroundStyle(StatsInk.full)
                        .symbolSize(28)
                case .line:
                    LineMark(x: .value(dateLabel, point.date, unit: unit), y: .value(title, point.value),
                             series: .value("Série", "value"))
                        .foregroundStyle(StatsInk.full)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
        }
        .statsPinnedDomain(window)
        .chartYScale(domain: .automatic(includesZero: false))
        .statsAxes(calendar: window.calendar)
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    /// « Variabilité et ligne de base, 30 jours : moyenne 56 ms, de 42 à 70 ms, ligne de base 54 ms. »
    private var summary: String {
        let values = points.map(\.value)
        let baselines = points.compactMap(\.baseline)
        let average = PulseFormat.integer(values.reduce(0, +) / Double(values.count), unit: unit)
        let low = PulseFormat.integer(values.min() ?? .nan, unit: nil)
        let high = PulseFormat.integer(values.max() ?? .nan, unit: unit)
        let period = window.period.title
        var text = String(localized: "\(title), \(period) : moyenne \(average), de \(low) à \(high)", bundle: .module)
        if !baselines.isEmpty {
            let baseline = PulseFormat.integer(baselines.reduce(0, +) / Double(baselines.count), unit: unit)
            text += String(localized: ", ligne de base \(baseline)", bundle: .module)
        }
        return text + "."
    }
}

// MARK: - Sommeil

/// Les heures dormies par nuit, la part profonde en encre pleine en bas de chaque barre.
private struct SleepChartCard: View {
    let points: [SleepPoint]
    let deepShare: Double?
    let window: StatsWindow

    static var emptyReason: String { String(localized: "aucune nuit de sommeil mesurée sur la période", bundle: .module) }

    var body: some View {
        StatsChartCard(title: String(localized: "Sommeil", bundle: .module)) {
            if points.isEmpty {
                StatsEmptyNote(reason: Self.emptyReason)
            } else {
                chart
                StatsLegend(items: [(String(localized: "Profond", bundle: .module), StatsInk.full),
                                    (String(localized: "Autres phases", bundle: .module), StatsInk.light)])
            }
        }
    }

    private var chart: some View {
        let unit = window.unit(of: window.period.chartBucket)
        let dateLabel = String(localized: "Nuit", bundle: .module)
        let hoursLabel = String(localized: "Heures", bundle: .module)
        return Chart(points) { point in
            let deep = min(point.deepMinutes ?? 0, point.asleepMinutes) / 60
            BarMark(x: .value(dateLabel, point.date, unit: unit), yStart: .value(hoursLabel, deep),
                    yEnd: .value(hoursLabel, point.asleepMinutes / 60))
                .foregroundStyle(StatsInk.light)
            if deep > 0 {
                BarMark(x: .value(dateLabel, point.date, unit: unit), yStart: .value(hoursLabel, 0),
                        yEnd: .value(hoursLabel, deep))
                    .foregroundStyle(StatsInk.full)
            }
        }
        .statsPinnedDomain(window)
        .statsAxes(calendar: window.calendar)
        .frame(height: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    /// « Sommeil, 30 jours : 7 h 12 en moyenne, profond 19 %. »
    private var summary: String {
        let average = StatsText.duration(minutes: points.map(\.asleepMinutes).reduce(0, +) / Double(points.count))
        let period = window.period.title
        var text = String(localized: "Sommeil, \(period) : \(average) en moyenne", bundle: .module)
        if let deepShare {
            text += String(localized: ", profond \(PulseFormat.integer(deepShare * 100, unit: "%"))", bundle: .module)
        }
        return text + "."
    }
}

// MARK: - Journées par état de forme

/// Le nombre de jours par catégorie de forme, en barres horizontales d'encre : le nom est toujours écrit.
private struct CategoriesCard: View {
    let categories: [CategoryCount]
    let window: StatsWindow

    var body: some View {
        StatsChartCard(title: String(localized: "Journées par état de forme", bundle: .module)) {
            if categories.allSatisfy({ $0.days == 0 }) {
                StatsEmptyNote(reason: String(localized: "aucun score du matin sur la période", bundle: .module))
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        let daysLabel = String(localized: "Jours", bundle: .module)
        let stateLabel = String(localized: "État", bundle: .module)
        return Chart(categories) { count in
            BarMark(x: .value(daysLabel, count.days), y: .value(stateLabel, count.category.localizedName))
                .foregroundStyle(StatsInk.full)
                .annotation(position: .trailing, spacing: 6) {
                    Text("\(count.days)")
                        .font(PulseFont.value(.caption, weight: .semibold))
                        .foregroundStyle(PulsePalette.text2)
                }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(PulsePalette.text2)
            }
        }
        .frame(height: CGFloat(categories.count) * 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    /// « Journées par état de forme, 30 jours : Forme optimale 6, Forme normale 18, Fatigue modérée 5, Surmenage 1. »
    private var summary: String {
        let counts = categories.map { "\($0.category.localizedName) \($0.days)" }.joined(separator: ", ")
        let period = window.period.title
        return String(localized: "Journées par état de forme, \(period) : \(counts).", bundle: .module)
    }
}

#if DEBUG
#Preview("Biométrie, 30 jours") {
    StatsSectionPreview(period: .month) { snapshot, window in BiometrySection(biometry: snapshot.biometry, window: window) }
}

#Preview("Biométrie, 1 an") {
    StatsSectionPreview(period: .year) { snapshot, window in BiometrySection(biometry: snapshot.biometry, window: window) }
}

#Preview("Biométrie, sans historique") {
    StatsSectionPreview(withHistory: false) { snapshot, window in BiometrySection(biometry: snapshot.biometry, window: window) }
}
#endif
