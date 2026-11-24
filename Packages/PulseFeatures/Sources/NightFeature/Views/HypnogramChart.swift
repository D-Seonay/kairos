import Charts
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// L'hypnogramme : une rangée libellée par phase, un bloc coloré par segment, de l'endormissement au réveil. Un trou sans
/// donnée reste vide. Les autres blocs comptés dans la nuit (une sieste) sont listés dessous.
struct HypnogramCard: View {
    let night: NightSleep
    let calendar: Calendar

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Phases de la nuit", bundle: .module))
                    .pulseEyebrow(PulsePalette.text2)
                    .accessibilityAddTraits(.isHeader)
                HypnogramChart(night: night, calendar: calendar)
                ForEach(night.otherBlocks.indices, id: \.self) { index in
                    Text(NightText.otherBlock(night.otherBlocks[index], calendar: calendar))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct HypnogramChart: View {
    let night: NightSleep
    let calendar: Calendar
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 40

    /// Les rangées de haut en bas : les quatre phases, ou Éveil et Endormi quand la source n'en donne pas.
    private var rows: [SleepStage] {
        night.hasStages ? SleepStage.chartOrder : [.awake, .asleepUnspecified]
    }

    /// Le nom de la rangée d'un segment ; un reste « sans phase » d'une nuit à phases va dans la rangée Léger.
    private func row(of stage: SleepStage) -> SleepStage {
        night.hasStages && stage == .asleepUnspecified ? .core : stage
    }

    var body: some View {
        // Les noms des rangées sont une colonne à part, centrée sur chaque bande : l'axe Y de Swift Charts les posait sur
        // la limite haute de la bande et par-dessus les blocs.
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows, id: \.self) { stage in
                    Text(stage.displayName)
                        .font(.caption)
                        .foregroundStyle(PulsePalette.text2)
                        .lineLimit(1)
                        .frame(height: rowHeight)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(true)
            chart
        }
    }

    private var chart: some View {
        let stageLabel = String(localized: "Phase", bundle: .module)
        let timeLabel = String(localized: "Heure", bundle: .module)
        let segments = night.segments
        return Chart(segments.indices, id: \.self) { index in
            RectangleMark(xStart: .value(timeLabel, segments[index].start), xEnd: .value(timeLabel, segments[index].end),
                          y: .value(stageLabel, row(of: segments[index].stage).displayName))
                .foregroundStyle(segments[index].stage.color)
                .accessibilityHidden(true)
        }
        .chartYScale(domain: rows.map(\.displayName))
        .chartXScale(domain: night.fellAsleep...max(night.wokeUp, night.fellAsleep.addingTimeInterval(60)))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 4])).foregroundStyle(PulsePalette.line)
                AxisValueLabel(format: .dateTime.hour().minute()).foregroundStyle(PulsePalette.muted)
            }
        }
        .chartYAxis(.hidden)
        // La zone de tracé fait exactement une rangée par phase, pour tomber en face de la colonne des noms.
        .chartPlotStyle { plot in plot.frame(height: CGFloat(rows.count) * rowHeight) }
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NightText.spokenSummary(night, calendar: calendar))
        .accessibilityChartDescriptor(NightChartDescriptor.hypnogram(night, calendar: calendar))
    }
}
