import Charts
import Foundation
import PulseDesignSystem
import PulseRecoveryEngine
import PulseServices
import SwiftUI

/// La vue Charge (spec M7 §6) : aiguë, chronique et ratio du jour, la courbe du ratio et son bilan, la charge par discipline,
/// puis les totaux de la période.
struct LoadSection: View {
    let load: LoadStats
    let window: StatsWindow

    var body: some View {
        VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
            StatsTileGrid(tiles: tiles)
            LoadRatioCard(load: load, window: window)
            LoadBarsCard(bars: load.bars, totals: load.totals, window: window)
            LoadTotalsCard(totals: load.totals)
        }
    }

    private var tiles: [StatsTileContent] {
        let today = load.today
        let reason = Self.missingRatioReason(daysUntilRatio: load.daysUntilRatio)
        var acuteDetails: [String] = []
        var acuteSpoken: [String] = []
        if let today, let before = load.acuteWeekBefore,
           let change = StatsText.change(StatsComparison(value: today.acute, previous: before)) {
            acuteDetails.append(String(localized: "\(change) vs semaine passée", bundle: .module))
            acuteSpoken.append(String(localized: "\(change) par rapport à la semaine passée", bundle: .module))
        }
        return [
            StatsTileContent(title: String(localized: "Charge aiguë, 7 j", bundle: .module),
                             value: today.map { StatsText.number($0.acute) }, details: acuteDetails, emptyReason: reason,
                             spokenTitle: String(localized: "Charge aiguë, 7 jours", bundle: .module), spokenDetails: acuteSpoken),
            StatsTileContent(title: String(localized: "Charge chronique, 28 j", bundle: .module),
                             value: today.map { StatsText.number($0.chronic) },
                             details: [String(localized: "moyenne par semaine", bundle: .module)], emptyReason: reason,
                             spokenTitle: String(localized: "Charge chronique, 28 jours", bundle: .module)),
            StatsTileContent(title: String(localized: "Ratio aigu / chronique", bundle: .module),
                             value: today.map { PulseFormat.decimal($0.ratio, maxFractionDigits: 2) },
                             details: today.map { [Self.zoneTitle($0.zone)] } ?? [], emptyReason: reason,
                             spokenTitle: String(localized: "Ratio aigu sur chronique", bundle: .module))
        ]
    }

    /// Pourquoi le ratio du jour manque : l'historique est trop court, ou ses 28 jours n'ont aucune charge.
    static func missingRatioReason(daysUntilRatio: Int?) -> String {
        guard let days = daysUntilRatio else {
            return String(localized: "aucune séance chronométrée sur les 28 derniers jours", bundle: .module)
        }
        return days == 1
            ? String(localized: "28 jours d'historique nécessaires, encore 1 jour", bundle: .module)
            : String(localized: "28 jours d'historique nécessaires, encore \(days) jours", bundle: .module)
    }

    static func zoneTitle(_ zone: ACWRZone) -> String {
        switch zone {
        case .undertraining: String(localized: "Sous-entraînement", bundle: .module)
        case .optimal: String(localized: "Zone optimale", bundle: .module)
        case .elevated: String(localized: "Charge élevée", bundle: .module)
        case .risk: String(localized: "Risque de blessure", bundle: .module)
        }
    }

    /// La phrase de bilan sous la courbe : factuelle, sans conseil.
    static func sentence(for verdict: LoadVerdict, calendar: Calendar) -> String {
        switch verdict {
        case .deload(let until):
            let date = StatsText.dayMonth(until, calendar: calendar)
            return String(localized: "Décharge en cours jusqu'au \(date)", bundle: .module)
        case .optimal(let weeks):
            return weeks == 1
                ? String(localized: "Dans la zone optimale depuis 1 semaine", bundle: .module)
                : String(localized: "Dans la zone optimale depuis \(weeks) semaines", bundle: .module)
        case .elevated(let days):
            return days == 1
                ? String(localized: "Au-dessus de 1,3 depuis 1 jour", bundle: .module)
                : String(localized: "Au-dessus de 1,3 depuis \(days) jours", bundle: .module)
        case .low:
            return String(localized: "Sous 0,8 : charge en baisse", bundle: .module)
        case .steady:
            return String(localized: "Dans la zone optimale", bundle: .module)
        }
    }
}

// MARK: - Courbe du ratio

/// La courbe du ratio, la bande optimale 0,8 – 1,3 et la ligne de risque à 1,5, seule touche de couleur ; avant 28 jours
/// d'historique, une phrase à la place.
private struct LoadRatioCard: View {
    let load: LoadStats
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    var body: some View {
        StatsChartCard(title: String(localized: "Ratio aigu / chronique", bundle: .module),
                       spokenTitle: String(localized: "Ratio aigu sur chronique", bundle: .module),
                       trailing: load.today.map { PulseFormat.decimal($0.ratio, maxFractionDigits: 2) }) {
            if let days = load.daysUntilRatio {
                Text(Self.waitingText(days: days))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if load.ratioPoints.isEmpty {
                // Un jour n'a pas de point quand les 28 jours qui finissent ce jour-là n'ont aucune charge.
                StatsEmptyNote(reason: String(localized: "aucune séance chronométrée sur la période ni sur les 28 jours d'avant",
                                              bundle: .module))
            } else {
                chart
            }
            if let verdict = load.verdict {
                Text(LoadSection.sentence(for: verdict, calendar: window.calendar))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var chart: some View {
        let points = load.ratioPoints
        let top = StatsChartDescriptors.ratioTop(points)
        let dayName = String(localized: "Jour", bundle: .module)
        let ratioName = String(localized: "Ratio", bundle: .module)
        return Chart {
            // Les décorations (bande, ligne de risque, courbe) sont tues : le résumé et le descripteur disent tout, et le point du
            // jour est lu une fois, avec sa date.
            RectangleMark(yStart: .value(String(localized: "Bas de la zone optimale", bundle: .module), 0.8),
                          yEnd: .value(String(localized: "Haut de la zone optimale", bundle: .module), 1.3))
                .foregroundStyle(StatsInk.zone)
                .accessibilityHidden(true)
            RuleMark(y: .value(String(localized: "Risque", bundle: .module), 1.5))
                .foregroundStyle(PulsePalette.signal)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text(String(localized: "1,5 risque", bundle: .module))
                        .pulseEyebrow(PulsePalette.signal)
                        .accessibilityHidden(true)
                }
                .accessibilityHidden(true)
            ForEach(points) { point in
                LineMark(x: .value(dayName, point.date), y: .value(ratioName, point.value))
                    .foregroundStyle(StatsInk.full)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .accessibilityHidden(true)
            }
            if let last = points.last {
                let spoken = StatsText.ratioPointSpoken(last, calendar: window.calendar)
                PointMark(x: .value(dayName, last.date), y: .value(ratioName, last.value))
                    .foregroundStyle(StatsInk.full)
                    .symbolSize(36)
                    .accessibilityLabel(spoken.label)
                    .accessibilityValue(spoken.value)
            }
        }
        .statsPinnedDomain(window)
        .chartYScale(domain: 0...top)
        .statsAxes(calendar: window.calendar)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.ratioSummary(points: points, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.ratio(points: points, window: window))
    }

    static func waitingText(days: Int) -> String {
        days == 1
            ? String(localized: "L'ACWR s'affiche après 28 jours d'entraînement (encore 1 jour)", bundle: .module)
            : String(localized: "L'ACWR s'affiche après 28 jours d'entraînement (encore \(days) jours)", bundle: .module)
    }
}

// MARK: - Charge par discipline

/// Les barres empilées musculation / course / vélo, en trois niveaux d'encre : par jour sur 7 jours, par semaine au-delà.
/// L'axe n'est pas borné à la période : la première barre de semaine couvre sa semaine entière (voir `LoadStats.bars`).
private struct LoadBarsCard: View {
    let bars: [LoadBar]
    /// Les totaux de la période seule : la première barre peut couvrir des jours d'avant la période.
    let totals: LoadTotals
    let window: StatsWindow
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 170

    private struct Entry: Identifiable {
        let start: Date
        let discipline: String
        let value: Double
        var id: String { "\(start.timeIntervalSinceReferenceDate)-\(discipline)" }
    }

    private static var strength: String { StatsText.strengthName }
    private static var run: String { StatsText.runName }
    private static var ride: String { StatsText.rideName }

    var body: some View {
        StatsChartCard(title: StatsText.loadTitle(window.period.loadBucket)) {
            if totals.totalLoad > 0 {
                chart
                StatsLegend(items: [(Self.strength, StatsInk.full), (Self.run, StatsInk.medium), (Self.ride, StatsInk.light)])
            } else {
                StatsEmptyNote(reason: String(localized: "aucune séance chronométrée sur la période", bundle: .module))
            }
        }
    }

    /// Toutes les barres, même à zéro : l'axe garde son étendue. Une barre à zéro est tue à VoiceOver.
    private var entries: [Entry] {
        bars.flatMap { bar in
            [Entry(start: bar.start, discipline: Self.strength, value: bar.strength),
             Entry(start: bar.start, discipline: Self.run, value: bar.run),
             Entry(start: bar.start, discipline: Self.ride, value: bar.ride)]
        }
    }

    private var chart: some View {
        let bucket = window.period.loadBucket
        let unit = window.unit(of: bucket)
        return Chart(entries) { entry in
            let spoken = StatsText.loadBarSpoken(start: entry.start, discipline: entry.discipline, value: entry.value,
                                                 bucket: bucket, calendar: window.calendar)
            BarMark(x: .value(String(localized: "Début", bundle: .module), entry.start, unit: unit),
                    y: .value(String(localized: "Charge", bundle: .module), entry.value))
                .foregroundStyle(by: .value(String(localized: "Discipline", bundle: .module), entry.discipline))
                .accessibilityHidden(entry.value == 0)
                .accessibilityLabel(spoken.label)
                .accessibilityValue(spoken.value)
        }
        .chartForegroundStyleScale(domain: [Self.strength, Self.run, Self.ride],
                                   range: [StatsInk.full, StatsInk.medium, StatsInk.light])
        .chartLegend(.hidden)
        .statsAxes(calendar: window.calendar)
        .frame(height: chartHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(StatsText.loadSummary(totals: totals, period: window.period))
        .accessibilityChartDescriptor(StatsChartDescriptors.load(bars: bars, totals: totals, window: window))
    }
}

// MARK: - Totaux

/// Les totaux de la période ; une ligne sans donnée (aucune course, aucun tonnage) n'apparaît pas plutôt que d'afficher 0.
private struct LoadTotalsCard: View {
    let totals: LoadTotals
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Row {
        let label: String
        let value: String
        let spoken: String
    }

    var body: some View {
        StatsChartCard(title: String(localized: "Totaux de la période", bundle: .module)) {
            if totals.sessions == 0 {
                StatsEmptyNote(reason: String(localized: "aucune séance sur la période", bundle: .module))
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    // Une ligne par total : l'étiquette, puis la valeur dessous, à pleine largeur.
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(rows, id: \.label) { row in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label).pulseEyebrow()
                                valueText(row)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.label)
                            .accessibilityValue(row.spoken)
                        }
                    }
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        ForEach(rows, id: \.label) { row in
                            // Un seul élément par ligne : la cellule de gauche est tue, celle de droite dit l'étiquette et la valeur.
                            GridRow {
                                Text(row.label).pulseEyebrow().accessibilityHidden(true)
                                valueText(row)
                                    .gridColumnAlignment(.trailing)
                                    .accessibilityLabel(row.label)
                                    .accessibilityValue(row.spoken)
                            }
                        }
                    }
                }
                if let share = totals.strengthShare {
                    ShareBar(strengthShare: share)
                }
            }
        }
    }

    private func valueText(_ row: Row) -> some View {
        Text(row.value)
            .font(PulseFont.value(.body))
            .foregroundStyle(PulsePalette.text)
    }

    private var rows: [Row] {
        var rows = [Row(label: String(localized: "Séances", bundle: .module), value: "\(totals.sessions)",
                        spoken: "\(totals.sessions)")]
        if totals.minutes > 0 {
            rows.append(Row(label: String(localized: "Durée totale", bundle: .module),
                            value: StatsText.duration(minutes: totals.minutes),
                            spoken: StatsText.durationSpoken(minutes: totals.minutes)))
        }
        if totals.tonnageKg > 0 {
            rows.append(Row(label: String(localized: "Tonnage", bundle: .module), value: "\(StatsText.number(totals.tonnageKg)) kg",
                            spoken: PulseSpoken.kilos(totals.tonnageKg.rounded())))
        }
        if totals.runMeters > 0 {
            rows.append(Row(label: String(localized: "Distance courue", bundle: .module),
                            value: StatsText.kilometers(meters: totals.runMeters),
                            spoken: StatsText.kilometersSpoken(meters: totals.runMeters)))
        }
        if totals.rideMeters > 0 {
            rows.append(Row(label: String(localized: "Distance roulée", bundle: .module),
                            value: StatsText.kilometers(meters: totals.rideMeters),
                            spoken: StatsText.kilometersSpoken(meters: totals.rideMeters)))
        }
        return rows
    }
}

/// La répartition de la charge : musculation en encre pleine, endurance (course et vélo) en encre moyenne.
private struct ShareBar: View {
    let strengthShare: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 6

    var body: some View {
        let strength = min(max(strengthShare, 0), 1)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout())
        VStack(alignment: .leading, spacing: 6) {
            layout {
                Text(String(localized: "Musculation \(PulseFormat.integer(strength * 100, unit: "%"))", bundle: .module))
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text(String(localized: "Endurance \(PulseFormat.integer((1 - strength) * 100, unit: "%"))", bundle: .module))
            }
            .font(.caption)
            .foregroundStyle(PulsePalette.text2)
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Capsule().fill(StatsInk.full).frame(width: proxy.size.width * strength)
                    Capsule().fill(StatsInk.medium)
                }
            }
            .frame(height: barHeight)
            .accessibilityHidden(true)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Charge, 30 jours") {
    StatsSectionPreview(period: .month) { snapshot, window in LoadSection(load: snapshot.load, window: window) }
}

#Preview("Charge, 7 jours") {
    StatsSectionPreview(period: .week) { snapshot, window in LoadSection(load: snapshot.load, window: window) }
}

#Preview("Charge, 1 an") {
    StatsSectionPreview(period: .year) { snapshot, window in LoadSection(load: snapshot.load, window: window) }
}

#Preview("Charge, sans historique") {
    StatsSectionPreview(withHistory: false) { snapshot, window in LoadSection(load: snapshot.load, window: window) }
}

#Preview("Charge, accessibilité 3") {
    StatsSectionPreview(period: .month) { snapshot, window in LoadSection(load: snapshot.load, window: window) }
        .dynamicTypeSize(.accessibility3)
}
#endif
