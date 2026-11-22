import PulseDesignSystem
import SwiftUI

/// La vue circulaire de l'écran verrouillé pour le widget Charge (ACWR).
public struct LoadWidgetCircularView: View {
    private let content: LoadWidgetContent

    @ScaledMetric(relativeTo: .footnote) private var ratioSize = 14

    public init(content: LoadWidgetContent) {
        self.content = content
    }

    public var body: some View {
        Gauge(value: min(max(content.ratio, 0.5), 2.0), in: 0.5...2.0) {
            Text("ACWR")
        } currentValueLabel: {
            Text(content.ratioText)
                .font(.system(size: ratioSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        // La jauge de l'écran verrouillé est fixe : l'étiquette VoiceOver porte tout le texte.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

#Preview("Circulaire Charge") {
    LoadWidgetCircularView(content: .sample(at: .now, calendar: .current))
}

#Preview("Circulaire Charge, accessibilité 3") {
    LoadWidgetCircularView(content: .sample(at: .now, calendar: .current))
        .dynamicTypeSize(.accessibility3)
        .frame(width: 76, height: 76)
}
