import PulseDesignSystem
import PulseServices
import SwiftUI

/// Un nom de Hevy : son nombre de séances et de séries, et ce qu'il devient. Toucher ouvre le menu du choix.
struct HevyMappingRow: View {
    let summary: HevyNameSummary
    let choiceLabel: String
    let isIgnored: Bool
    let needsReview: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.name)
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.leading)
                    Text(counts)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                    HStack(spacing: 8) {
                        Text(choiceLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isIgnored ? PulsePalette.text2 : PulsePalette.text)
                            .multilineTextAlignment(.leading)
                        if needsReview {
                            Badge(text: String(localized: "À vérifier", bundle: .module), color: PulsePalette.warn)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(PulsePalette.surface, in: shape)
            .overlay(shape.strokeBorder(needsReview ? PulsePalette.warn : PulsePalette.line))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(String(localized: "Change l'exercice associé", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
    }

    private var counts: String {
        let sessions = String(localized: "\(summary.sessionCount) séances", bundle: .module)
        let sets = String(localized: "\(summary.setCount) séries", bundle: .module)
        return String(localized: "\(sessions) · \(sets)", bundle: .module)
    }

    private var accessibilityText: String {
        let review = needsReview ? String(localized: ", à vérifier", bundle: .module) : ""
        return String(localized: "\(summary.name), \(counts). Choix : \(choiceLabel)\(review)", bundle: .module)
    }
}
