import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le signal discret d'un plateau, sans carte autour : un titre, le calcul dit en clair, puis les trois pistes. La fiche de
/// l'exercice et le récap de séance le posent chacun dans leur carte. `onVariant`, s'il est donné, ajoute « Voir une variante ».
public struct ExercisePlateauView: View {
    private let title: String
    private let explanation: String
    private let spokenExplanation: String
    private let tips: [String]
    private let variantName: String?
    private let onVariant: (() -> Void)?

    public init(title: String, plateau: ExercisePlateau, variantName: String?, calendar: Calendar,
                onVariant: (() -> Void)? = nil) {
        self.title = title
        explanation = plateau.explanation(calendar: calendar)
        spokenExplanation = plateau.explanation(calendar: calendar, spoken: true)
        tips = ExercisePlateau.tips(variant: variantName)
        self.variantName = variantName
        self.onVariant = onVariant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
            } icon: {
                Image(systemName: "chart.line.flattrend.xyaxis")
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
            Text(explanation)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spokenExplanation)
            Text(String(localized: "Pistes, une à la fois", bundle: .module))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tips.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(index + 1).")
                            .font(.footnote.weight(.bold).monospacedDigit())
                            .foregroundStyle(PulsePalette.text2)
                            .accessibilityHidden(true)
                        Text(tips[index])
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Piste \(index + 1) : \(tips[index])", bundle: .module))
                }
            }
            if let variantName, let onVariant {
                Button(action: onVariant) {
                    Text(String(localized: "Voir une variante : \(variantName)", bundle: .module))
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(PulseDesignSystem.LinkButtonStyle())
                .frame(minHeight: 44)
                .accessibilityHint(String(localized: "Ouvre la fiche de l'exercice", bundle: .module))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
