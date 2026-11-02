import PulseDesignSystem
import SwiftUI

/// En attendant la séance en direct : la séance du jour à suivre en salle, exercice par exercice.
struct StartSessionSheet: View {
    let lines: [SessionPlanLine]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PulsePalette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                    Text(String(localized: "La séance en direct arrive bientôt", bundle: .module))
                        .font(.title.weight(.heavy))
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(String(localized: "En attendant, voici ta séance à suivre en salle :", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                    ObsidianCard {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                if index > 0 {
                                    Divider().overlay(PulsePalette.line)
                                }
                                PlanLineRow(line: line)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(String(localized: "Fermer", bundle: .module)) { dismiss() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .padding(PulseMetrics.spacing)
            }
        }
    }
}

/// L'exercice, puis « 3 × 6–10 · repos 2 min 45 » ; lu d'un seul tenant par VoiceOver.
private struct PlanLineRow: View {
    let line: SessionPlanLine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.name)
                .font(.body.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
            Text(verbatim: "\(line.prescription) · \(line.rest)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(PulsePalette.text2)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
