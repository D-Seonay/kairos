import PulseDesignSystem
import SwiftUI

/// La vue circulaire de l'écran verrouillé pour le widget Charge (ACWR).
public struct LoadWidgetCircularView: View {
    private let content: LoadWidgetContent

    public init(content: LoadWidgetContent) {
        self.content = content
    }

    public var body: some View {
        Gauge(value: min(max(content.ratio, 0.5), 2.0), in: 0.5...2.0) {
            Text("ACWR")
        } currentValueLabel: {
            Text(content.ratioText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

#Preview("Circulaire Charge") {
    LoadWidgetCircularView(content: .sample(at: .now, calendar: .current))
}
