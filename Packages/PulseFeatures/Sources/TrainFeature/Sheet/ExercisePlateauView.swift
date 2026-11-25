import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le signal discret d'un plateau, sans carte autour : un titre, le calcul dit en clair pour chaque exercice concerné, puis les
/// trois pistes une seule fois. La fiche de l'exercice et le récap de séance le posent chacun dans leur carte. `onVariant`, s'il
/// est donné, ajoute « Voir une variante ».
public struct ExercisePlateauView: View {
    /// Un exercice sur un plateau : son nom (aucun dans sa propre fiche), le calcul et, quand plusieurs exercices se partagent
    /// les pistes, sa variante.
    public struct Item {
        let name: String?
        let explanation: String
        let spokenExplanation: String
        let variant: String?

        public init(name: String?, plateau: ExercisePlateau, calendar: Calendar, variant: String? = nil) {
            self.name = name
            explanation = plateau.explanation(calendar: calendar)
            spokenExplanation = plateau.explanation(calendar: calendar, spoken: true)
            self.variant = variant
        }
    }

    private let title: String
    private let items: [Item]
    private let tips: [String]
    private let variantName: String?
    private let onVariant: (() -> Void)?

    /// `variantName` nourrit la piste de la variante ; avec plusieurs exercices, chaque `Item` porte la sienne.
    public init(title: String, items: [Item], variantName: String?, onVariant: (() -> Void)? = nil) {
        self.title = title
        self.items = items
        tips = ExercisePlateau.tips(variant: variantName)
        self.variantName = variantName
        self.onVariant = onVariant
    }

    /// Le plateau d'un seul exercice, dans sa fiche.
    public init(title: String, plateau: ExercisePlateau, variantName: String?, calendar: Calendar,
                onVariant: (() -> Void)? = nil) {
        self.init(title: title, items: [Item(name: nil, plateau: plateau, calendar: calendar)], variantName: variantName,
                  onVariant: onVariant)
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
            ForEach(items.indices, id: \.self) { index in
                item(items[index])
            }
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

    /// Le nom de l'exercice (s'il y en a un), le calcul, puis sa variante quand les pistes sont partagées.
    private func item(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let name = item.name {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text)
            }
            Text(item.explanation)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(item.spokenExplanation)
            if let variant = item.variant {
                Text(String(localized: "Variante possible : \(variant).", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
    }
}
