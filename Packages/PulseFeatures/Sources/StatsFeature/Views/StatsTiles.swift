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
        bucket == .day ? .day : .weekOfYear
    }

    /// « +6 % vs 30 j précédents » ; `nil` sans période précédente.
    func comparisonText(_ comparison: StatsComparison?) -> String? {
        StatsText.change(comparison).map { String(localized: "\($0) vs \(period.days) j précédents", bundle: .module) }
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

    var id: String { title }
}

/// Les tuiles sur deux colonnes, une seule aux tailles d'accessibilité (comme les tendances de l'accueil).
struct StatsTileGrid: View {
    let tiles: [StatsTileContent]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tiles) { StatsTile(content: $0) }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
    }
}

/// Une tuile : VoiceOver la lit d'une phrase.
struct StatsTile: View {
    let content: StatsTileContent
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 34

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .pulseEyebrow()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let value = content.value {
                    Text(value)
                        .font(PulseFont.score(size: valueSize))
                        .foregroundStyle(PulsePalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let parts = [content.title] + (content.value.map { [$0] + content.details }
            ?? [content.emptyTitle, content.emptyReason])
        return parts.joined(separator: ", ")
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

/// La carte d'un graphique : son étiquette d'instrument, une valeur à droite, puis le graphique.
struct StatsChartCard<Content: View>: View {
    let title: String
    var trailing: String?
    @ViewBuilder let content: Content

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .pulseEyebrow(PulsePalette.text2)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(PulseFont.value(.headline))
                            .foregroundStyle(PulsePalette.text)
                    }
                }
                content
            }
        }
    }
}

/// La légende d'un graphique en encre : un carré par série.
struct StatsLegend: View {
    let items: [(label: String, style: Color)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(items[index].style).frame(width: 10, height: 10)
                    Text(items[index].label)
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
        .accessibilityHidden(true)
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
}

extension View {
    /// Borne l'axe des dates à la période et rogne la zone du graphique : un point ou une barre de semaine daté du lundi
    /// d'avant la période ne déborde pas sur les étiquettes de l'axe.
    func statsPinnedDomain(_ window: StatsWindow) -> some View {
        chartXScale(domain: window.domain)
            .chartPlotStyle { $0.clipped() }
    }
}

/// Les niveaux d'encre des séries : la plus importante en encre pleine, les autres de plus en plus claires.
enum StatsInk {
    static let full = PulsePalette.ink
    static let medium = PulsePalette.ink.opacity(0.5)
    static let light = PulsePalette.ink.opacity(0.22)
    static let zone = PulsePalette.ink.opacity(0.07)
}
