import PulseDesignSystem
import PulseRecoveryEngine
import SwiftUI

/// « Charge d'entraînement » : la zone du ratio aigu / chronique en pastille, la jauge et le conseil. Tant que l'historique
/// ne couvre pas 28 jours, un texte explique à la place quand la jauge apparaîtra.
struct LoadCard: View {
    let content: LoadCardContent

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                switch content {
                case .hidden:
                    Text(LoadCardContent.hiddenText)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                case .ratio(let value, let valueText, let zoneTitle, let advice):
                    LoadGauge(ratio: value, accessibilityLabel: gaugeLabel(valueText: valueText, zoneTitle: zoneTitle))
                    Text(sentence(valueText: valueText, advice: advice))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    /// Le titre et la pastille de zone ; la pastille passe sous le titre quand le texte grandit.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                title
                Spacer(minLength: 8)
                zoneBadge
            }
            VStack(alignment: .leading, spacing: 8) {
                title
                zoneBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: some View {
        Text(String(localized: "Charge d'entraînement", bundle: .module))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulsePalette.text)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var zoneBadge: some View {
        if case .ratio(let value, _, let zoneTitle, _) = content {
            let tint = Self.tint(for: ACWRZone(ratio: value))
            Text(zoneTitle)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(minHeight: 24)
                .background(tint.opacity(0.16), in: Capsule())
        }
    }

    /// « Ratio aigu / chronique 1,12. Tu peux maintenir ce rythme cette semaine. », le ratio en évidence.
    private func sentence(valueText: String, advice: String) -> AttributedString {
        var text = AttributedString(String(localized: "Ratio aigu / chronique \(valueText). \(advice)", bundle: .module))
        if let range = text.range(of: valueText) {
            text[range].font = .footnote.weight(.bold).monospacedDigit()
            text[range].foregroundColor = PulsePalette.text
        }
        return text
    }

    private func gaugeLabel(valueText: String, zoneTitle: String) -> String {
        String(localized: "Charge d'entraînement : ratio \(valueText), \(zoneTitle)", bundle: .module)
    }

    private static func tint(for zone: ACWRZone) -> Color {
        switch zone {
        case .undertraining: PulsePalette.run
        case .optimal: PulsePalette.ok
        case .elevated: PulsePalette.warn
        case .risk: PulsePalette.bad
        }
    }
}

#Preview("Charge, ratio 1,12") {
    LoadCard(content: .ratio(value: 1.12, valueText: "1,12", zoneTitle: "Zone optimale",
                             advice: "Tu peux maintenir ce rythme cette semaine."))
        .padding()
        .background(PulsePalette.background)
}

#Preview("Charge, cachée") {
    LoadCard(content: .hidden)
        .padding()
        .background(PulsePalette.background)
}
