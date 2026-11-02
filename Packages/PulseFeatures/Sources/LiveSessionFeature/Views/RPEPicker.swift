import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le choix du RPE par pilules, de 6 à 10 par pas de 0,5 (spec M4 §14.4), et « — » pour l'effacer. Choisir ferme le panneau.
struct RPEPicker: View {
    /// Les valeurs que le modèle accepte.
    static let values: [Double] = stride(from: 6.0, through: 10.0, by: 0.5).map { $0 }

    let title: String
    let selection: Double?
    let onSelect: (Double?) -> Void
    let onClose: () -> Void
    @Environment(\.pulseTheme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulsePalette.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .foregroundStyle(PulsePalette.text2)
                        .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Fermer le choix du RPE", bundle: .module))
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Self.values, id: \.self) { value in
                    pill(label: Self.label(for: value), isSelected: selection == value, spoken: Self.spokenLabel(for: value),
                         identifier: LiveSessionIdentifiers.rpePrefix + Self.label(for: value)) { onSelect(value) }
                }
                pill(label: "\u{2014}", isSelected: false, spoken: String(localized: "Effacer le RPE", bundle: .module),
                     identifier: LiveSessionIdentifiers.rpePrefix + "clear") { onSelect(nil) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(PulsePalette.surface)
        .accessibilityElement(children: .contain)
    }

    private func pill(label: String, isSelected: Bool, spoken: String, identifier: String,
                      action: @escaping () -> Void) -> some View {
        let palette = PulsePalette.accent(for: theme)
        return Button(action: action) {
            Text(label)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isSelected ? Color(palette.accentInk) : PulsePalette.text)
                .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight)
                .background(isSelected ? Color(palette.accent) : PulsePalette.surface2, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// « 7,5 », « 8 » : une pilule.
    nonisolated static func label(for value: Double) -> String {
        PulseFormat.decimal(value, maxFractionDigits: 1)
    }

    nonisolated static func spokenLabel(for value: Double) -> String {
        String(localized: "RPE \(label(for: value))", bundle: .module)
    }

    /// « Développé couché · Série 2 · RPE ».
    nonisolated static func title(exercise: String, setIndex: Int) -> String {
        String(localized: "\(exercise) · Série \(setIndex + 1) · RPE", bundle: .module)
    }
}
