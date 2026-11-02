import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le clavier numérique intégré (spec M4 §14.4), sans clavier système : chiffres, virgule, effacement, −/+ de l'incrément et
/// « Suivant ». Chaque touche fait 56 pt. La barre du haut dit ce qui est édité, et ferme le clavier.
struct NumericKeypad: View {
    let title: String
    let field: KeypadField.Kind
    let increment: Double
    let onKey: (KeypadInput.Key) -> Void
    let onClose: () -> Void

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
                .accessibilityLabel(String(localized: "Fermer le clavier", bundle: .module))
            }
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow { digit(1); digit(2); digit(3); step(-1) }
                GridRow { digit(4); digit(5); digit(6); step(1) }
                GridRow { digit(7); digit(8); digit(9); deleteKey }
                GridRow { commaKey; digit(0); nextKey.gridCellColumns(2) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
        .background(PulsePalette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LiveSessionIdentifiers.keypad)
    }

    private func digit(_ value: Int) -> some View {
        KeypadKey(label: Text("\(value)"), spoken: "\(value)", identifier: Self.identifier(for: .digit(value))) {
            onKey(.digit(value))
        }
    }

    private var commaKey: some View {
        KeypadKey(label: Text(","), spoken: String(localized: "Virgule", bundle: .module),
                  identifier: Self.identifier(for: .comma)) { onKey(.comma) }
            .disabled(field != .weight)
    }

    private var deleteKey: some View {
        KeypadKey(label: Text(Image(systemName: "delete.left")), spoken: String(localized: "Effacer", bundle: .module),
                  identifier: Self.identifier(for: .delete)) { onKey(.delete) }
    }

    private func step(_ sign: Int) -> some View {
        KeypadKey(label: Text(Self.stepText(for: field, increment: increment, sign: sign)),
                  spoken: Self.stepSpokenText(for: field, increment: increment, sign: sign),
                  identifier: Self.identifier(for: sign < 0 ? .minus : .plus)) { onKey(sign < 0 ? .minus : .plus) }
    }

    private var nextKey: some View {
        KeypadKey(label: Text(String(localized: "Suivant", bundle: .module)), spoken: String(localized: "Suivant", bundle: .module),
                  identifier: Self.identifier(for: .next), isProminent: true) { onKey(.next) }
    }
}

private struct KeypadKey: View {
    let label: Text
    let spoken: String
    let identifier: String
    var isProminent = false
    let action: () -> Void
    @Environment(\.pulseTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Button(action: action) {
            label
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(isProminent ? Color(palette.accentInk) : PulsePalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight)
                .background(isProminent ? Color(palette.accent) : PulsePalette.surface2, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
    }
}

// MARK: - Textes

extension NumericKeypad {
    /// « Développé couché · Série 2 · kg » : ce que le clavier édite.
    nonisolated static func title(exercise: String, setIndex: Int, field: KeypadField.Kind, loadKind: LoadKind) -> String {
        let fieldName = switch field {
        case .weight: LiveSetRow.weightColumnTitle(for: loadKind)
        case .reps: String(localized: "Répétitions", bundle: .module)
        case .duration: String(localized: "Secondes", bundle: .module)
        }
        return String(localized: "\(exercise) · Série \(setIndex + 1) · \(fieldName)", bundle: .module)
    }

    /// Le pas de −/+ : l'incrément de l'exercice pour la charge, 1 répétition, 5 secondes. « +2,5 », « −1 ».
    nonisolated static func stepText(for field: KeypadField.Kind, increment: Double, sign: Int) -> String {
        let amount = PulseFormat.decimal(stepSize(for: field, increment: increment), maxFractionDigits: 2)
        return (sign < 0 ? "\u{2212}" : "+") + amount
    }

    nonisolated static func stepSpokenText(for field: KeypadField.Kind, increment: Double, sign: Int) -> String {
        let amount = PulseFormat.decimal(stepSize(for: field, increment: increment), maxFractionDigits: 2)
        return sign < 0 ? String(localized: "Retirer \(amount)", bundle: .module)
            : String(localized: "Ajouter \(amount)", bundle: .module)
    }

    private nonisolated static func stepSize(for field: KeypadField.Kind, increment: Double) -> Double {
        switch field {
        case .weight: increment
        case .reps: KeypadInput.repsStep
        case .duration: KeypadInput.secondsStep
        }
    }

    /// « live.key.7 », « live.key.comma » : l'identifiant d'une touche.
    nonisolated static func identifier(for key: KeypadInput.Key) -> String {
        let name = switch key {
        case let .digit(value): "\(value)"
        case .comma: "comma"
        case .delete: "delete"
        case .minus: "minus"
        case .plus: "plus"
        case .next: "next"
        }
        return LiveSessionIdentifiers.keypadKeyPrefix + name
    }
}
