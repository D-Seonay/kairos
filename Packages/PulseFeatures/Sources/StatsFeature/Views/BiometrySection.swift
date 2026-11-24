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
    /// Ouvre l'écran Nuit ; sans lui, la carte Sommeil n'a pas de lien.
    var onOpenNights: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            StatsTileGrid(tiles: tiles)
            BaselineChartCard(title: String(localized: "Variabilité et ligne de base", bundle: .module), unit: "ms",
                              measure: .hrv, points: biometry.hrvPoints, style: .points, window: window)
            BaselineChartCard(title: String(localized: "FC au repos", bundle: .module), unit: "bpm",
                              measure: .restingHeartRate, points: biometry.restingPoints, style: .line, window: window)
            SleepChartCard(points: biometry.sleepPoints, deepShare: biometry.deepShare, stageShares: biometry.stageShares,
                           window: window, onOpenNights: onOpenNights)
            CategoriesCard(categories: biometry.categories, window: window)
        }
    }

    private var tiles: [StatsTileContent] {
        let noNight = String(localized: "aucune nuit mesurée sur la période", bundle: .module)
        var sleepDetails = details(biometry.sleepMinutes)
        var sleepSpoken = spokenDetails(biometry.sleepMinutes)
        if let shares = biometry.stageShares {
            // « profond 18 % · paradoxal 22 % · léger 60 % » : les nuits qui ont leurs phases.
            let deep = PulseFormat.integer(shares.deep * 100, unit: "%")
            let rem = PulseFormat.integer(shares.rem * 100, unit: "%")
            let core = PulseFormat.integer(shares.core * 100, unit: "%")
            let share = String(localized: "profond \(deep) · paradoxal \(rem) · léger \(core)", bundle: .module)
            sleepDetails.insert(share, at: 0)
            sleepSpoken.insert(share.replacingOccurrences(of: " · ", with: ", "), at: 0)
        } else if let deep = biometry.deepShare {
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
    /// L'unité écrite sur l'axe des valeurs.
    let unit: String
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
        let dateUnit = window.unit(of: bucket)
        let dateLabel = StatsText.nightAxisName(bucket)
        let valueLabel = measure.spokenName
        return Chart {
            ForEach(points) { point in
                if let baseline = point.baseline {
                    LineMark(x: .value(dateLabel, point.date, unit: dateUnit), y: .value(valueLabel, baseline),
                             series: .value(String(localized: "Série", bundle: .module), "baseline"))
                        .foregroundStyle(StatsInk.medium)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .accessibilityHidden(true)
                }
                switch style {
                case .points:
                    let spoken = StatsText.baselinePointSpoken(measure: measure, point: point, bucket: bucket,
                                                               calendar: window.calendar)
                    PointMark(x: .value(dateLabel, point.date, unit: dateUnit), y: .value(valueLabel, point.value))
                        .foregroundStyle(StatsInk.full)
                        .symbolSize(28)
                        .accessibilityLabel(spoken.label)
                        .accessibilityValue(spoken.value)
                case .line:
                    // La FC au repos est une courbe : seule la ligne se dessine, le descripteur donne chaque valeur.
                    LineMark(x: .value(dateLabel, point.date, unit: dateUnit), y: .value(valueLabel, point.value),
                             series: .value(String(localized: "Série", bundle: .module), "value"))
                        .foregroundStyle(StatsInk.full)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                        .accessibilityHidden(true)
                }
            }
            // La courbe n'a pas de point par nuit : son dernier point est lu, avec sa date ; le descripteur donne le reste.
            if style == .line, let last = points.last {
                let spoken = StatsText.baselinePointSpoken(measure: measure, point: last, bucket: bucket, calendar: window.calendar)
                PointMark(x: .value(dateLabel, last.date, unit: dateUnit), y: .value(valueLabel, last.value))
                    .foregroundStyle(StatsInk.full)
                    .symbolSize(36)
                    .accessibilityLabel(spoken.label)
                    .accessibilityValue(spoken.value)
            }
        }
        .statsPinnedDomain(window)
        .chartYScale(domain: .automatic(includesZero: false))
        .statsAxes(calendar: window.calendar, yUnit: unit)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.baselineSummary(measure: measure, points: points, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.baseline(measure: measure, points: points, window: window))
    }
}

// MARK: - Sommeil

/// Les heures dormies par nuit. Une barre à phases s'empile de bas en haut : profond, léger, paradoxal, sans phase, chacun de
/// sa couleur. Une barre d'avant les phases garde l'ancien découpage à l'encre : le profond en bas, le reste au-dessus.
private struct SleepChartCard: View {
    let points: [SleepPoint]
    let deepShare: Double?
    let stageShares: StageShares?
    let window: StatsWindow
    var onOpenNights: (() -> Void)?
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 160

    static var emptyReason: String { String(localized: "aucune nuit de sommeil mesurée sur la période", bundle: .module) }

    var body: some View {
        StatsChartCard(title: String(localized: "Sommeil", bundle: .module)) {
            if points.isEmpty {
                StatsEmptyNote(reason: Self.emptyReason)
            } else {
                chart
                StatsLegend(items: legend)
            }
            if let onOpenNights {
                Button(action: onOpenNights) {
                    Label(String(localized: "Voir les nuits", bundle: .module), systemImage: "moon.zzz")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PulsePalette.text)
            }
        }
    }

    /// Seules les tranches réellement dessinées sur la période (voir `SleepChartLayers.legend`).
    private var legend: [(label: String, style: Color)] {
        SleepChartLayers.legend(of: points)
    }

    private var chart: some View {
        let bucket = window.period.chartBucket
        let unit = window.unit(of: bucket)
        let dateLabel = StatsText.nightAxisName(bucket)
        let hoursLabel = String(localized: "Heures de sommeil", bundle: .module)
        return Chart(points) { point in
            let spoken = StatsText.sleepPointSpoken(point: point, bucket: bucket, calendar: window.calendar)
            let layers = SleepChartLayers.layers(of: point)
            // La barre entière est lue une fois, sur sa première tranche, avec le total et les phases ; les autres sont tues.
            ForEach(layers) { layer in
                BarMark(x: .value(dateLabel, point.date, unit: unit), yStart: .value(hoursLabel, layer.start),
                        yEnd: .value(hoursLabel, layer.end))
                    .foregroundStyle(layer.style)
                    .accessibilityLabel(spoken.label)
                    .accessibilityValue(spoken.value)
                    .accessibilityHidden(layer.id != layers.first?.id)
            }
        }
        .statsPinnedDomain(window)
        .statsAxes(calendar: window.calendar, yUnit: "h")
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.sleepSummary(points: points, deepShare: deepShare, stageShares: stageShares,
                                                   period: window.period, calendar: window.calendar))
        .accessibilityChartDescriptor(StatsChartDescriptors.sleep(points: points, deepShare: deepShare, stageShares: stageShares,
                                                                  window: window))
    }
}

// MARK: - Journées par état de forme

/// Le nombre de jours par catégorie de forme, en barres horizontales d'encre : le nom est toujours écrit.
///
/// Des rangées SwiftUI plutôt qu'un `Chart` : l'axe Y de Swift Charts posait chaque nom sur la limite haute de sa bande,
/// sous la barre de la rangée précédente. Ici le nom et le nombre de jours tiennent une ligne, la barre est en dessous.
private struct CategoriesCard: View {
    let categories: [CategoryCount]
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var rowSpacing: CGFloat = 14

    var body: some View {
        StatsChartCard(title: String(localized: "Journées par état de forme", bundle: .module)) {
            if categories.allSatisfy({ $0.days == 0 }) {
                StatsEmptyNote(reason: String(localized: "aucun score du matin sur la période", bundle: .module))
            } else {
                rows
            }
        }
    }

    private var rows: some View {
        let maxDays = max(categories.map(\.days).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(categories) { count in
                row(count, fraction: CGFloat(count.days) / CGFloat(maxDays))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.categoriesSummary(categories, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.categories(categories, window: window))
    }

    private func row(_ count: CategoryCount, fraction: CGFloat) -> some View {
        let spoken = StatsText.categorySpoken(count)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(count.category.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(count.days)")
                    .font(PulseFont.value(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(PulsePalette.text)
            }
            // Le fond reste visible à zéro jour : la catégorie existe, elle est simplement vide sur la période.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(StatsInk.zone)
                    RoundedRectangle(cornerRadius: 2).fill(StatsInk.full)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: barHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.label)
        .accessibilityValue(spoken.value)
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
