import Charts
import Foundation
import PulseDesignSystem
import PulseServices
import SwiftUI

/// Ce que les sections savent de la période affichée : son intervalle (le domaine des courbes) et le calendrier des grains.
struct StatsWindow {
    let period: StatsPeriod
    let interval: DateInterval
    let calendar: Calendar

    init(period: StatsPeriod, now: Date, calendar: Calendar) {
        self.period = period
        self.interval = period.interval(now: now, calendar: calendar)
        self.calendar = calendar
    }

    /// Le domaine des courbes : l'intervalle de la période, pour qu'un point de semaine daté du lundi d'avant n'étire pas l'axe.
    var domain: ClosedRange<Date> { interval.start...interval.end }

    /// Le dernier jour de la période : aujourd'hui.
    var today: Date { calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end }

    /// L'unité d'un grain de courbe ou de barre.
    func unit(of bucket: StatsBucket) -> Calendar.Component {
        StatsChartReadings.unit(of: bucket)
    }

    /// « +6 % par rapport aux 30 jours précédents », « … à l'année précédente » sur un an ; `nil` sans période précédente.
    func comparisonText(_ comparison: StatsComparison?) -> String? {
        StatsText.comparisonSpoken(comparison, days: period.days)
    }
}

/// Une tuile chiffrée : l'étiquette, le gros chiffre fin et ses précisions ; sans valeur, « Pas assez de données » (ou un titre
/// plus juste) et la raison.
struct StatsTileContent: Identifiable {
    let title: String
    let value: String?
    var details: [String] = []
    /// Pourquoi la valeur manque, affiché sous le titre vide.
    let emptyReason: String
    /// Le titre affiché sans valeur : « Pas assez de données », sauf quand l'absence est un fait (« Pas encore de semaine
    /// réussie »).
    var emptyTitle: String = StatsEmptyNote.title
    /// Ce que VoiceOver dit à la place du texte écrit quand il porte une abréviation ou une unité (« 58 bpm »).
    var spokenTitle: String?
    var spokenValue: String?
    var spokenDetails: [String]?

    var id: String { title }
}

/// Les tuiles sur deux colonnes, une seule aux tailles d'accessibilité (comme les tendances de l'accueil). Les tuiles d'une même
/// ligne prennent la hauteur de la plus haute.
struct StatsTileGrid: View {
    let tiles: [StatsTileContent]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(rows[index]) { StatsTile(content: $0) }
                    // Une ligne incomplète garde la largeur d'une colonne à sa tuile.
                    ForEach(rows[index].count..<columnCount, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
                // La ligne prend la hauteur de sa plus haute tuile, que les autres remplissent.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var columnCount: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 2 }

    private var rows: [[StatsTileContent]] {
        stride(from: 0, to: tiles.count, by: columnCount).map { Array(tiles[$0..<min($0 + columnCount, tiles.count)]) }
    }
}

/// Une tuile : VoiceOver la lit d'une phrase.
struct StatsTile: View {
    let content: StatsTileContent
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 34
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Aux tailles d'accessibilité, ni la valeur ni le titre ne rétrécissent ni ne se coupent : la tuile grandit.
        let isLarge = dynamicTypeSize.isAccessibilitySize
        ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .pulseEyebrow()
                    .lineLimit(isLarge ? nil : 2)
                    .minimumScaleFactor(isLarge ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if let value = content.value {
                    Text(value)
                        .font(PulseFont.score(size: valueSize))
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(isLarge ? nil : 1)
                        .minimumScaleFactor(isLarge ? 1 : 0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(content.details, id: \.self) { detail in
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    StatsEmptyNote(reason: content.emptyReason, heading: content.emptyTitle)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatsText.tileSpoken(content))
    }
}

/// « Pas assez de données » et sa raison, à la place d'un chiffre ou d'un graphique : jamais un zéro (spec M7 §2).
struct StatsEmptyNote: View {
    let reason: String
    var heading: String = StatsEmptyNote.title

    nonisolated static var title: String { String(localized: "Pas assez de données", bundle: .module) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heading)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text2)
            Text(reason)
                .font(.caption)
                .foregroundStyle(PulsePalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// La carte d'un graphique : son étiquette d'instrument, une valeur à droite, puis le graphique. Aux tailles d'accessibilité,
/// la valeur passe sous le titre. `spokenTitle` dit le titre quand il porte une abréviation (« FC au repos »).
struct StatsChartCard<Content: View>: View {
    let title: String
    var spokenTitle: String?
    var trailing: String?
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
        }
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(title)
                .pulseEyebrow(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spokenTitle ?? title)
                .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if let trailing {
                Text(trailing)
                    .font(PulseFont.value(.headline))
                    .foregroundStyle(PulsePalette.text)
            }
        }
    }
}

/// La légende d'un graphique en encre : un carré par série.
struct StatsLegend: View {
    let items: [(label: String, style: Color)]

    @ScaledMetric(relativeTo: .caption) private var swatch: CGFloat = 10

    var body: some View {
        // Les entrées tiennent sur une ligne, sinon l'une sous l'autre : aucune ne déborde.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { entries }
            VStack(alignment: .leading, spacing: 6) { entries }
        }
        .accessibilityHidden(true)
    }

    private var entries: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(items[index].style).frame(width: swatch, height: swatch)
                Text(items[index].label)
                    .font(.caption)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
    }
}

/// Les axes communs des graphiques : filets pointillés, étiquettes grises, dates en « 12 nov. ».
extension View {
    func statsAxes(calendar: Calendar) -> some View {
        chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(PulsePalette.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel().foregroundStyle(PulsePalette.muted)
            }
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
    }

    /// Les mêmes axes, avec l'unité des valeurs sur l'axe vertical (« 60 ms », « 7 h »).
    func statsAxes(calendar: Calendar, yUnit: String) -> some View {
        chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(PulsePalette.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel {
                    Text(value.as(Double.self).map { "\(PulseFormat.decimal($0, maxFractionDigits: 1)) \(yUnit)" } ?? "")
                }
                .foregroundStyle(PulsePalette.muted)
            }
        }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
    }
}

extension View {
    /// Borne l'axe des dates à la période et rogne la zone du graphique : un point ou une barre de semaine daté du lundi
    /// d'avant la période ne déborde pas sur les étiquettes de l'axe.
    func statsPinnedDomain(_ window: StatsWindow) -> some View {
        chartXScale(domain: window.domain)
            .chartPlotStyle { $0.clipped() }
    }
}

/// Les niveaux d'encre des séries : la plus importante en encre pleine, les autres de plus en plus claires. Une série qui porte
/// une information atteint 3:1 contre le papier (`StatsInkContrastTests`) ; seul `zone`, un fond dit aussi par le texte, reste
/// plus pâle.
enum StatsInk {
    static let fullOpacity = 1.0
    static let mediumOpacity = 0.72
    static let lightOpacity = 0.5
    static let zoneOpacity = 0.07
    /// Les cinq niveaux d'assiduité : le niveau 0 est le fond de la grille, les niveaux 1 à 4 de plus en plus encrés.
    static let attendanceOpacities = [zoneOpacity, 0.5, 0.67, 0.83, 1.0]

    static let full = PulsePalette.ink
    static let medium = PulsePalette.ink.opacity(mediumOpacity)
    static let light = PulsePalette.ink.opacity(lightOpacity)
    static let zone = PulsePalette.ink.opacity(zoneOpacity)
}
