import Charts
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La courbe du meilleur 1RM estimé de chaque séance. Une phrase de résumé tient lieu d'étiquette VoiceOver ; le descripteur
/// donne le graphique audio et le détail point par point.
struct ExerciseProgressionChart: View {
    let points: [ChartPoint]
    let summary: String
    let descriptor: PulseChartDescriptor
    /// La date et la valeur d'un point dites en mots : « 26 octobre », « 80 kilos ».
    let spokenPoint: (ChartPoint) -> (label: String, value: String)
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        let dateName = String(localized: "Date", bundle: .module)
        let valueName = String(localized: "Maximum estimé en kilos", bundle: .module)
        Chart(points) { point in
            let spoken = spokenPoint(point)
            // La ligne est décorative : seul le point est lu, une fois, avec sa date et sa valeur.
            LineMark(x: .value(dateName, point.date), y: .value(valueName, point.value))
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                .accessibilityHidden(true)
            PointMark(x: .value(dateName, point.date), y: .value(valueName, point.value))
                .foregroundStyle(accent)
                .symbolSize(40)
                .accessibilityLabel(spoken.label)
                .accessibilityValue(spoken.value)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
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
        .frame(height: 170)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(summary)
        .accessibilityChartDescriptor(descriptor)
    }
}
