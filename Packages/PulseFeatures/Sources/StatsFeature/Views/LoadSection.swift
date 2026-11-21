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
            LoadBarsCard(bars: load.bars, window: window)
            LoadTotalsCard(totals: load.totals)
        }
    }

    private var tiles: [StatsTileContent] {
        let today = load.today
        let reason = Self.missingRatioReason(daysUntilRatio: load.daysUntilRatio)
        var acuteDetails: [String] = []
        if let today, let before = load.acuteWeekBefore,
           let change = StatsText.change(StatsComparison(value: today.acute, previous: before)) {
            acuteDetails.append(String(localized: "\(change) vs semaine passée", bundle: .module))
        }
        return [
            StatsTileContent(title: String(localized: "Charge aiguë, 7 j", bundle: .module),
                             value: today.map { StatsText.number($0.acute) }, details: acuteDetails, emptyReason: reason),
            StatsTileContent(title: String(localized: "Charge chronique, 28 j", bundle: .module),
                             value: today.map { StatsText.number($0.chronic) },
                             details: [String(localized: "moyenne par semaine", bundle: .module)], emptyReason: reason),
            StatsTileContent(title: String(localized: "Ratio aigu / chronique", bundle: .module),
                             value: today.map { PulseFormat.decimal($0.ratio, maxFractionDigits: 2) },
                             details: today.map { [Self.zoneTitle($0.zone)] } ?? [], emptyReason: reason)
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

    var body: some View {
        StatsChartCard(title: String(localized: "Ratio aigu / chronique", bundle: .module),
                       trailing: load.today.map { PulseFormat.decimal($0.ratio, maxFractionDigits: 2) }) {
            if let days = load.daysUntilRatio {
                Text(Self.waitingText(days: days))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            } else if load.ratioPoints.isEmpty {
                StatsEmptyNote(reason: String(localized: "aucune séance chronométrée sur les 28 jours d'avant la période",
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
        let top = max(2, (points.map(\.value).max() ?? 0) * 1.1)
        return Chart {
            RectangleMark(yStart: .value("Bas", 0.8), yEnd: .value("Haut", 1.3))
                .foregroundStyle(StatsInk.zone)
            RuleMark(y: .value(String(localized: "Risque", bundle: .module), 1.5))
                .foregroundStyle(PulsePalette.signal)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text(String(localized: "1,5 risque", bundle: .module)).pulseEyebrow(PulsePalette.signal)
                }
            ForEach(points) { point in
                LineMark(x: .value(String(localized: "Jour", bundle: .module), point.date),
                         y: .value(String(localized: "Ratio", bundle: .module), point.value))
                    .foregroundStyle(StatsInk.full)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
            if let last = points.last {
                PointMark(x: .value(String(localized: "Jour", bundle: .module), last.date),
                          y: .value(String(localized: "Ratio", bundle: .module), last.value))
                    .foregroundStyle(StatsInk.full)
                    .symbolSize(36)
            }
        }
        .chartXScale(domain: window.domain)
        .chartYScale(domain: 0...top)
        .statsAxes(calendar: window.calendar)
        .frame(height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary(points))
    }

    /// « Ratio aigu / chronique, 30 jours : dernier 1,12, de 0,86 à 1,31. Zone optimale de 0,8 à 1,3, risque à 1,5. »
    private func summary(_ points: [StatsPoint]) -> String {
        let values = points.map(\.value)
        func text(_ value: Double?) -> String { PulseFormat.decimal(value ?? .nan, maxFractionDigits: 2) }
        let period = window.period.title
        let (last, low, high) = (text(values.last), text(values.min()), text(values.max()))
        return String(localized: """
            Ratio aigu / chronique, \(period) : dernier \(last), de \(low) à \(high). Zone optimale de 0,8 à 1,3, risque à 1,5.
            """, bundle: .module)
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
    let window: StatsWindow

    private struct Entry: Identifiable {
        let start: Date
        let discipline: String
        let value: Double
        var id: String { "\(start.timeIntervalSinceReferenceDate)-\(discipline)" }
    }

    private static var strength: String { String(localized: "Musculation", bundle: .module) }
    private static var run: String { String(localized: "Course", bundle: .module) }
    private static var ride: String { String(localized: "Vélo", bundle: .module) }

    var body: some View {
        StatsChartCard(title: window.period.loadBucket == .day
                       ? String(localized: "Charge par jour", bundle: .module)
                       : String(localized: "Charge par semaine", bundle: .module)) {
            if total(\.strength) + total(\.run) + total(\.ride) > 0 {
                chart
                StatsLegend(items: [(Self.strength, StatsInk.full), (Self.run, StatsInk.medium), (Self.ride, StatsInk.light)])
            } else {
                StatsEmptyNote(reason: String(localized: "aucune séance chronométrée sur la période", bundle: .module))
            }
        }
    }

    private var entries: [Entry] {
        bars.flatMap { bar in
            [Entry(start: bar.start, discipline: Self.strength, value: bar.strength),
             Entry(start: bar.start, discipline: Self.run, value: bar.run),
             Entry(start: bar.start, discipline: Self.ride, value: bar.ride)]
        }
    }

    private var chart: some View {
        let unit = window.unit(of: window.period.loadBucket)
        return Chart(entries) { entry in
            BarMark(x: .value(String(localized: "Début", bundle: .module), entry.start, unit: unit),
                    y: .value(String(localized: "Charge", bundle: .module), entry.value))
                .foregroundStyle(by: .value(String(localized: "Discipline", bundle: .module), entry.discipline))
        }
        .chartForegroundStyleScale(domain: [Self.strength, Self.run, Self.ride],
                                   range: [StatsInk.full, StatsInk.medium, StatsInk.light])
        .chartLegend(.hidden)
        .statsAxes(calendar: window.calendar)
        .frame(height: 170)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private func total(_ value: KeyPath<LoadBar, Double>) -> Double {
        bars.reduce(0) { $0 + $1[keyPath: value] }
    }

    /// « Charge par semaine, 30 jours : 8 450 en tout, dont musculation 5 200, course 2 650, vélo 600. »
    private var summary: String {
        let period = window.period.title
        let all = StatsText.number(total(\.strength) + total(\.run) + total(\.ride))
        let (strength, run, ride) = (StatsText.number(total(\.strength)), StatsText.number(total(\.run)),
                                     StatsText.number(total(\.ride)))
        return String(localized: """
            Charge, \(period) : \(all) en tout, dont musculation \(strength), course \(run), vélo \(ride).
            """, bundle: .module)
    }
}

// MARK: - Totaux

/// Les totaux de la période ; une ligne sans donnée (aucune course, aucun tonnage) n'apparaît pas plutôt que d'afficher 0.
private struct LoadTotalsCard: View {
    let totals: LoadTotals

    var body: some View {
        StatsChartCard(title: String(localized: "Totaux de la période", bundle: .module)) {
            if totals.sessions == 0 {
                StatsEmptyNote(reason: String(localized: "aucune séance terminée sur la période", bundle: .module))
            } else {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    ForEach(rows, id: \.label) { row in
                        GridRow {
                            Text(row.label).pulseEyebrow()
                            Text(row.value)
                                .font(PulseFont.value(.body))
                                .foregroundStyle(PulsePalette.text)
                                .gridColumnAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                if let share = totals.strengthShare {
                    ShareBar(strengthShare: share)
                }
            }
        }
    }

    private var rows: [(label: String, value: String)] {
        var rows = [(String(localized: "Séances", bundle: .module), "\(totals.sessions)")]
        if totals.minutes > 0 {
            rows.append((String(localized: "Durée totale", bundle: .module), StatsText.duration(minutes: totals.minutes)))
        }
        if totals.tonnageKg > 0 {
            rows.append((String(localized: "Tonnage", bundle: .module), "\(StatsText.number(totals.tonnageKg)) kg"))
        }
        if totals.runMeters > 0 {
            rows.append((String(localized: "Distance courue", bundle: .module), StatsText.kilometers(meters: totals.runMeters)))
        }
        if totals.rideMeters > 0 {
            rows.append((String(localized: "Distance roulée", bundle: .module), StatsText.kilometers(meters: totals.rideMeters)))
        }
        return rows.map { (label: $0.0, value: $0.1) }
    }
}

/// La répartition de la charge : musculation en encre pleine, endurance (course et vélo) en encre moyenne.
private struct ShareBar: View {
    let strengthShare: Double

    var body: some View {
        let strength = min(max(strengthShare, 0), 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(localized: "Musculation \(PulseFormat.integer(strength * 100, unit: "%"))", bundle: .module))
                Spacer()
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
            .frame(height: 6)
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
#endif
