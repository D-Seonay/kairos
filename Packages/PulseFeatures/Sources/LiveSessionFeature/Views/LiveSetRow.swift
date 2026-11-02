import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Une série : le numéro (son menu change le type), le précédent, la charge, les répétitions (ou secondes), le RPE et la coche.
/// Les cibles font 56 pt. À partir des tailles d'accessibilité, la ligne passe sur deux lignes.
struct LiveSetRow: View {
    static let targetHeight: CGFloat = 56
    /// Les largeurs des colonnes, que l'en-tête des colonnes reprend ; le précédent prend le reste.
    static let badgeWidth: CGFloat = 36
    static let weightWidth: CGFloat = 64
    static let valueWidth: CGFloat = 56
    static let rpeWidth: CGFloat = 48

    let model: LiveSessionModel
    let exercise: LiveExercise
    let exerciseIndex: Int
    let set: LiveSet
    let index: Int
    @Binding var rpeSet: UUID?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        typeMenu
                        previous
                        checkButton
                    }
                    HStack(spacing: 8) {
                        weightCell
                        valueCell
                        rpeCell
                    }
                }
            } else {
                HStack(spacing: 6) {
                    typeMenu
                    previous
                    weightCell
                    valueCell
                    rpeCell
                    checkButton
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    // MARK: Numéro et précédent

    private var typeMenu: some View {
        Menu {
            Picker(String(localized: "Type de série", bundle: .module), selection: typeBinding) {
                Text(String(localized: "Échauffement", bundle: .module)).tag(SetType.warmup)
                Text(String(localized: "Normale", bundle: .module)).tag(SetType.working)
                Text(String(localized: "Dégressive", bundle: .module)).tag(SetType.drop)
                Text(String(localized: "À l'échec", bundle: .module)).tag(SetType.failure)
            }
            Button(role: .destructive) {
                Task { await model.deleteSet(set.id) }
            } label: {
                Label(String(localized: "Supprimer la série", bundle: .module), systemImage: "trash")
            }
        } label: {
            Text(Self.badge(for: set.setType, index: index))
                .font(.headline.monospacedDigit())
                .foregroundStyle(badgeColor)
                .frame(width: Self.badgeWidth, height: Self.targetHeight)
        }
        .accessibilityLabel(String(localized: "Type de la série \(index + 1)", bundle: .module))
        .accessibilityValue(Self.typeName(set.setType) ?? String(localized: "normale", bundle: .module))
    }

    private var typeBinding: Binding<SetType> {
        Binding(get: { set.setType }, set: { type in Task { await model.setType(type, set: set.id) } })
    }

    private var badgeColor: Color {
        switch set.setType {
        case .working: PulsePalette.text2
        case .warmup: PulsePalette.warn
        case .drop: PulsePalette.run
        case .failure: PulsePalette.bad
        }
    }

    private var previous: some View {
        Text(set.previous ?? "\u{2014}")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(PulsePalette.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: Self.targetHeight)
            .accessibilityLabel(set.previous.map { String(localized: "Précédent \($0)", bundle: .module) }
                                ?? String(localized: "Pas de série précédente", bundle: .module))
    }

    // MARK: Valeurs

    private var weightCell: some View {
        let kind = KeypadField.Kind.weight
        return ValueCell(
            text: text(for: kind, saved: Self.weightText(set.weightKg, loadKind: exercise.loadKind)),
            isEmpty: set.weightKg == nil && exercise.loadKind == .external,
            isProposed: Self.isProposed(kind, in: set), isFocused: model.focus == field(kind), width: width(Self.weightWidth),
            label: Self.weightColumnTitle(for: exercise.loadKind),
            identifier: LiveSessionIdentifiers.weight(exercise: exerciseIndex, set: index)
        ) { model.focus(field(kind)); rpeSet = nil }
    }

    private var valueCell: some View {
        let kind: KeypadField.Kind = exercise.tracksDuration ? .duration : .reps
        let saved = exercise.tracksDuration ? set.durationSeconds : set.reps
        return ValueCell(
            text: text(for: kind, saved: saved.map(String.init) ?? "\u{2013}"), isEmpty: saved == nil,
            isProposed: Self.isProposed(kind, in: set), isFocused: model.focus == field(kind), width: width(Self.valueWidth),
            label: exercise.tracksDuration ? String(localized: "Secondes", bundle: .module)
                : String(localized: "Répétitions", bundle: .module),
            identifier: LiveSessionIdentifiers.reps(exercise: exerciseIndex, set: index)
        ) { model.focus(field(kind)); rpeSet = nil }
    }

    private var rpeCell: some View {
        ValueCell(
            text: set.rpe.map { PulseFormat.decimal($0, maxFractionDigits: 1) } ?? "\u{2013}", isEmpty: set.rpe == nil,
            isProposed: false, isFocused: rpeSet == set.id, width: width(Self.rpeWidth), label: String(localized: "RPE", bundle: .module),
            identifier: LiveSessionIdentifiers.rpe(exercise: exerciseIndex, set: index)
        ) {
            model.focus(nil)
            rpeSet = rpeSet == set.id ? nil : set.id
        }
    }

    /// Une largeur fixe sur la ligne unique ; les cellules se partagent la ligne aux tailles d'accessibilité.
    private func width(_ fixed: CGFloat) -> CGFloat? {
        typeSize.isAccessibilitySize ? nil : fixed
    }

    private func field(_ kind: KeypadField.Kind) -> KeypadField {
        KeypadField(exercise: exercise.id, set: set.id, kind: kind)
    }

    /// Le champ que le clavier édite montre son tampon, virgule en attente comprise.
    private func text(for kind: KeypadField.Kind, saved: String) -> String {
        model.focus == field(kind) && !model.keypad.text.isEmpty ? model.keypad.text : saved
    }

    // MARK: Coche

    private var checkButton: some View {
        let isDone = set.completedAt != nil
        return Button {
            Task { await model.tap(set: set.id) }
        } label: {
            Image(systemName: "checkmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(isDone ? PulsePalette.liveBackground : PulsePalette.muted)
                .frame(width: Self.targetHeight, height: Self.targetHeight)
                .background(isDone ? PulsePalette.ok : PulsePalette.surface2, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityText(for: set, index: index, loadKind: exercise.loadKind,
                                                   tracksDuration: exercise.tracksDuration))
        .accessibilityHint(isDone ? String(localized: "Annule la validation de la série", bundle: .module)
                            : String(localized: "Valide la série", bundle: .module))
        .accessibilityIdentifier(LiveSessionIdentifiers.check(exercise: exerciseIndex, set: index))
    }
}

/// Une valeur touchable : accent tant qu'elle est proposée, neutre une fois modifiée, estompée sans valeur.
private struct ValueCell: View {
    let text: String
    let isEmpty: Bool
    let isProposed: Bool
    let isFocused: Bool
    let width: CGFloat?
    let label: String
    let identifier: String
    let action: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        Button(action: action) {
            Text(text)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isEmpty ? PulsePalette.muted : (isProposed ? accent : PulsePalette.text))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width)
                .frame(maxWidth: width == nil ? .infinity : nil, minHeight: LiveSetRow.targetHeight)
                .background(isFocused ? PulsePalette.surface2 : PulsePalette.surface, in: shape)
                .overlay(shape.strokeBorder(isFocused ? accent : PulsePalette.line, lineWidth: isFocused ? 2 : 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isEmpty ? String(localized: "vide", bundle: .module) : text)
        .accessibilityIdentifier(identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
    }
}
