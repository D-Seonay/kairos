import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le RPE global de la course, de 1 à 10, ou « Pas noté » (spec V2a §4.5, §5.2). Aucune valeur n'est présélectionnée : tant que
/// rien n'est touché, aucune pastille n'est allumée, pas même « Pas noté ». Cinq colonnes, trois aux tailles d'accessibilité.
struct RunEffortPicker: View {
    @Binding var selection: Int?
    /// « Pas noté » a été choisi : la pastille s'allume, la valeur reste `nil`.
    @State private var choseUnset = false
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 3 : 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Effort global ressenti", bundle: .module))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(Self.prompt)
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(RunRecapModel.rpeRange), id: \.self) { value in
                    pill("\(value)", isSelected: selection == value, spoken: Self.spoken(value),
                         identifier: RunIdentifiers.effortPrefix + "\(value)") {
                        selection = value
                        choseUnset = false
                    }
                }
            }
            pill(String(localized: "Pas noté", bundle: .module), isSelected: selection == nil && choseUnset,
                 spoken: String(localized: "Pas noté", bundle: .module), identifier: RunIdentifiers.effortUnset) {
                selection = nil
                choseUnset = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// « Note ton effort : sans note, Pulse l'estime ».
    static var prompt: String {
        String(localized: "Note ton effort : sans note, Pulse l'estime", bundle: .module)
    }

    /// « 7 sur 10 ».
    static func spoken(_ value: Int) -> String {
        PulseSpoken.outOf(value, RunRecapModel.rpeRange.upperBound)
    }

    private func pill(_ label: String, isSelected: Bool, spoken: String, identifier: String,
                      action: @escaping () -> Void) -> some View {
        let palette = PulsePalette.accent(for: theme)
        return Button(action: action) {
            Text(label)
                .font(.headline.monospacedDigit())
                .foregroundStyle(isSelected ? Color(palette.accentInk) : PulsePalette.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if isSelected {
                        Capsule().fill(Color(palette.accent))
                    } else {
                        Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
