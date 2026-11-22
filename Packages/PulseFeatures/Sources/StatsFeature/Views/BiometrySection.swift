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
                              measure: .hrv, points: biometry.hrvPoints, style: .points, window: window)
            BaselineChartCard(title: String(localized: "FC au repos", bundle: .module),
                              measure: .restingHeartRate, points: biometry.restingPoints, style: .line, window: window)
            SleepChartCard(points: biometry.sleepPoints, deepShare: biometry.deepShare, window: window)
            CategoriesCard(categories: biometry.categories, window: window)
        }
    }

    private var tiles: [StatsTileContent] {
        let noNight = String(localized: "aucune nuit mesurée sur la période", bundle: .module)
        var sleepDetails = details(biometry.sleepMinutes)
        var sleepSpoken = spokenDetails(biometry.sleepMinutes)
        if let deep = biometry.deepShare {
            let share = String(localized: "profond \(PulseFormat.integer(deep * 100, unit: "%"))", bundle: .module)
            sleepDetails.insert(share, at: 0)
            sleepSpoken.insert(share, at: 0)
        }
        return [
            StatsTileContent(title: String(localized: "Variabilité moyenne", bundle: .module),
                             value: biometry.hrv.map { PulseFormat.integer($0.value, unit: "ms") },
                             details: details(biometry.hrv), emptyReason: noNight,
                             spokenValue: biometry.hrv.map { BiometricMeasure.hrv.spoken($0.value) },
                             spokenDetails: spokenDetails(biometry.hrv)),
            StatsTileContent(title: String(localized: "FC au repos", bundle: .module),
                             value: biometry.restingHeartRate.map { PulseFormat.integer($0.value, unit: "bpm") },
                             details: details(biometry.restingHeartRate), emptyReason: noNight,
                             spokenTitle: BiometricMeasure.restingHeartRate.spokenName,
                             spokenValue: biometry.restingHeartRate.map { BiometricMeasure.restingHeartRate.spoken($0.value) },
                             spokenDetails: spokenDetails(biometry.restingHeartRate)),
            StatsTileContent(title: String(localized: "Sommeil moyen", bundle: .module),
                             value: biometry.sleepMinutes.map { StatsText.duration(minutes: $0.value) },
                             details: sleepDetails, emptyReason: SleepChartCard.emptyReason,
                             spokenValue: biometry.sleepMinutes.map { StatsText.durationSpoken(minutes: $0.value) },
                             spokenDetails: sleepSpoken),
            StatsTileContent(title: String(localized: "Récupération moyenne", bundle: .module),
                             value: biometry.score.map { PulseFormat.integer($0.value, unit: nil) },
                             details: details(biometry.score),
                             emptyReason: String(localized: "aucun score du matin sur la période", bundle: .module),
                             spokenValue: biometry.score.map { PulseSpoken.outOf(Int($0.value.rounded()), 100) },
                             spokenDetails: spokenDetails(biometry.score))
        ]
    }

    private func details(_ comparison: StatsComparison?) -> [String] {
        window.comparisonText(comparison).map { [$0] } ?? []
    }

    private func spokenDetails(_ comparison: StatsComparison?) -> [String] {
        StatsText.comparisonSpoken(comparison, days: window.period.days).map { [$0] } ?? []
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
    let measure: BiometricMeasure
    let points: [BaselinePoint]
    let style: Style
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160

    var body: some View {
        StatsChartCard(title: title, spokenTitle: measure.spokenName) {
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
        let bucket = window.period.chartBucket
        let unit = window.unit(of: bucket)
        let dateLabel = StatsText.nightAxisName(bucket)
        let valueLabel = measure.spokenName
        return Chart {
            ForEach(points) { point in
                if let baseline = point.baseline {
                    LineMark(x: .value(dateLabel, point.date, unit: unit), y: .value(valueLabel, baseline),
                             series: .value(String(localized: "Série", bundle: .module), "baseline"))
                        .foregroundStyle(StatsInk.medium)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .accessibilityHidden(true)
                }
                switch style {
                case .points:
                    let spoken = StatsText.baselinePointSpoken(measure: measure, point: point, bucket: bucket,
                                                               calendar: window.calendar)
                    PointMark(x: .value(dateLabel, point.date, unit: unit), y: .value(valueLabel, point.value))
                        .foregroundStyle(StatsInk.full)
                        .symbolSize(28)
                        .accessibilityLabel(spoken.label)
                        .accessibilityValue(spoken.value)
                case .line:
                    // La FC au repos est une courbe : seule la ligne se dessine, le descripteur donne chaque valeur.
                    LineMark(x: .value(dateLabel, point.date, unit: unit), y: .value(valueLabel, point.value),
                             series: .value(String(localized: "Série", bundle: .module), "value"))
                        .foregroundStyle(StatsInk.full)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                        .accessibilityHidden(true)
                }
            }
            // La courbe n'a pas de point par nuit : son dernier point est lu, avec sa date ; le descripteur donne le reste.
            if style == .line, let last = points.last {
                let spoken = StatsText.baselinePointSpoken(measure: measure, point: last, bucket: bucket, calendar: window.calendar)
                PointMark(x: .value(dateLabel, last.date, unit: unit), y: .value(valueLabel, last.value))
                    .foregroundStyle(StatsInk.full)
                    .symbolSize(36)
                    .accessibilityLabel(spoken.label)
                    .accessibilityValue(spoken.value)
            }
        }
        .statsPinnedDomain(window)
        .chartYScale(domain: .automatic(includesZero: false))
        .statsAxes(calendar: window.calendar)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.baselineSummary(measure: measure, points: points, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.baseline(measure: measure, points: points, window: window))
    }
}

// MARK: - Sommeil

/// Les heures dormies par nuit, la part profonde en encre pleine en bas de chaque barre.
private struct SleepChartCard: View {
    let points: [SleepPoint]
    let deepShare: Double?
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160

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
        let bucket = window.period.chartBucket
        let unit = window.unit(of: bucket)
        let dateLabel = StatsText.nightAxisName(bucket)
        let hoursLabel = String(localized: "Heures de sommeil", bundle: .module)
        return Chart(points) { point in
            let deep = min(point.deepMinutes ?? 0, point.asleepMinutes) / 60
            let spoken = StatsText.sleepPointSpoken(point: point, bucket: bucket, calendar: window.calendar)
            // La barre entière est lue une fois, avec le total et la part profonde ; la part profonde, dessinée par-dessus, est tue.
            BarMark(x: .value(dateLabel, point.date, unit: unit), yStart: .value(hoursLabel, deep),
                    yEnd: .value(hoursLabel, point.asleepMinutes / 60))
                .foregroundStyle(StatsInk.light)
                .accessibilityLabel(spoken.label)
                .accessibilityValue(spoken.value)
            if deep > 0 {
                BarMark(x: .value(dateLabel, point.date, unit: unit), yStart: .value(hoursLabel, 0),
                        yEnd: .value(hoursLabel, deep))
                    .foregroundStyle(StatsInk.full)
                    .accessibilityHidden(true)
            }
        }
        .statsPinnedDomain(window)
        .statsAxes(calendar: window.calendar)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.sleepSummary(points: points, deepShare: deepShare, period: window.period, bucket: bucket,
                                                   calendar: window.calendar))
        .accessibilityChartDescriptor(StatsChartDescriptors.sleep(points: points, deepShare: deepShare, window: window))
    }
}

// MARK: - Journées par état de forme

/// Le nombre de jours par catégorie de forme, en barres horizontales d'encre : le nom est toujours écrit.
private struct CategoriesCard: View {
    let categories: [CategoryCount]
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 34

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
            let spoken = StatsText.categorySpoken(count)
            BarMark(x: .value(daysLabel, count.days), y: .value(stateLabel, count.category.localizedName))
                .foregroundStyle(StatsInk.full)
                .annotation(position: .trailing, spacing: 6) {
                    Text("\(count.days)")
                        .font(PulseFont.value(.caption, weight: .semibold))
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityHidden(true)
                }
                .accessibilityLabel(spoken.label)
                .accessibilityValue(spoken.value)
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(PulsePalette.text2)
            }
        }
        .frame(height: CGFloat(categories.count) * rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.categoriesSummary(categories, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.categories(categories, window: window))
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

#Preview("Biométrie, accessibilité 3") {
    StatsSectionPreview(period: .month) { snapshot, window in BiometrySection(biometry: snapshot.biometry, window: window) }
        .dynamicTypeSize(.accessibility3)
}
#endif
