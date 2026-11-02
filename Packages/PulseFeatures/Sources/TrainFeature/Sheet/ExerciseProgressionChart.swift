import Charts
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// La courbe du meilleur 1RM estimé de chaque séance. Un résumé en une phrase tient lieu d'étiquette VoiceOver.
struct ExerciseProgressionChart: View {
    let points: [ChartPoint]
    let summary: String
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        Chart(points) { point in
            LineMark(x: .value(String(localized: "Date", bundle: .module), point.date),
                     y: .value(String(localized: "1RM estimé (kg)", bundle: .module), point.value))
                .foregroundStyle(accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            PointMark(x: .value(String(localized: "Date", bundle: .module), point.date),
                      y: .value(String(localized: "1RM estimé (kg)", bundle: .module), point.value))
                .foregroundStyle(accent)
                .symbolSize(40)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }
}
