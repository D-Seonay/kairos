import Charts
import PulseDesignSystem
import SwiftUI

extension View {
    /// Toucher ou glisser sur un graphique à axe de dates trace une règle verticale sur la marque la plus proche et écrit sa
    /// date et ses valeurs au-dessus ; relâcher les masque. `reading` lit la marque la plus proche d'une date
    /// (`StatsChartReadings`). Rien ne s'anime : la règle suit le doigt, avec ou sans « Réduire les animations ».
    func statsChartSelection(_ reading: @escaping (Date) -> StatsChartReading?) -> some View {
        modifier(StatsChartSelectionModifier(reading: reading))
    }
}

private struct StatsChartSelectionModifier: ViewModifier {
    let reading: (Date) -> StatsChartReading?
    @State private var selected: Date?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        let current = selected.flatMap(reading)
        content
            .chartXSelection(value: $selected)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if let current, let plotAnchor = proxy.plotFrame, let x = proxy.position(forX: current.date) {
                        let plot = geometry[plotAnchor]
                        StatsSelectionMarker(reading: current, plot: plot, lineX: plot.minX + min(max(x, 0), plot.width),
                                             width: geometry.size.width)
                    }
                }
                // L'annotation double les marques et le descripteur que VoiceOver lit déjà : elle est tue, et le doigt passe.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .sensoryFeedback(.selection, trigger: current?.date) { _, new in new != nil }
            .onChange(of: current?.date) {
                // Glisser sous VoiceOver (double touche maintenue) dit la marque atteinte.
                guard voiceOverEnabled, let current else { return }
                PulseAnnouncement.post(current.spoken)
            }
    }
}

/// La règle sur toute la hauteur du tracé et l'annotation en haut, du côté où elle a le plus de place.
private struct StatsSelectionMarker: View {
    let reading: StatsChartReading
    let plot: CGRect
    let lineX: CGFloat
    let width: CGFloat

    var body: some View {
        let leading = lineX < plot.midX
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(PulsePalette.ink)
                .frame(width: 1, height: plot.height)
                .offset(x: lineX - 0.5, y: plot.minY)
            StatsSelectionLabel(reading: reading)
                .padding(leading ? .leading : .trailing, leading ? lineX + 6 : width - lineX + 6)
                .frame(width: width, alignment: leading ? .leading : .trailing)
                .offset(y: plot.minY)
        }
        .frame(width: width, alignment: .topLeading)
    }
}

/// La date, puis une valeur par ligne, sur une étiquette de papier cernée d'un filet.
private struct StatsSelectionLabel: View {
    let reading: StatsChartReading

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reading.title)
                .pulseEyebrow(PulsePalette.text2)
            ForEach(reading.lines.indices, id: \.self) { index in
                Text(reading.lines[index])
                    .font(PulseFont.value(.footnote, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(PulsePalette.text)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PulsePalette.line))
    }
}
