import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Une série : le numéro (son menu change le type), le précédent, la charge, les répétitions (ou secondes), le RPE et la coche.
/// Les cibles font 56 pt de haut et au moins 44 de large. Dès `xxLarge`, la ligne passe sur deux lignes et chaque cellule
/// porte son titre.
struct LiveSetRow: View {
    static let targetHeight: CGFloat = 56
    /// Les largeurs des colonnes à la taille de texte par défaut, que l'en-tête des colonnes reprend ; elles suivent la taille
    /// du texte. Le précédent prend le reste.
    static let badgeWidth: CGFloat = 44
    static let weightWidth: CGFloat = 64
    static let valueWidth: CGFloat = 56
    static let rpeWidth: CGFloat = 48
    /// La marge de la ligne : 8 et non 12, pour que la pastille du type garde 44 pt de large.
    static let horizontalPadding: CGFloat = 8

    let model: LiveSessionModel
    let exercise: LiveExercise
    let exerciseIndex: Int
    let set: LiveSet
    let index: Int
    @Binding var rpeSet: UUID?
    @ScaledMetric(relativeTo: .title2) private var weightWidth = LiveSetRow.weightWidth
    @ScaledMetric(relativeTo: .title2) private var valueWidth = LiveSetRow.valueWidth
    @ScaledMetric(relativeTo: .title2) private var rpeWidth = LiveSetRow.rpeWidth
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if Self.usesStackedLayout(typeSize) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        typeMenu
                        previous
                        checkButton
                    }
                    HStack(alignment: .bottom, spacing: 8) {
                        titled(Self.cellTitle(for: .weight, loadKind: exercise.loadKind)) { weightCell }
                        titled(Self.cellTitle(for: valueKind, loadKind: exercise.loadKind)) { valueCell }
                        titled(String(localized: "RPE", bundle: .module)) { rpeCell }
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
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, 4)
        // Le rotor « Conteneurs » annonce la série en entier ; à l'intérieur, chaque cellule dit sa valeur.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.accessibilityText(for: set, index: index, loadKind: exercise.loadKind,
                                                   tracksDuration: exercise.tracksDuration))
    }

    /// Une cellule et son titre visible, au-dessus, quand la ligne passe sur deux lignes. Le titre est muet : la cellule le dit.
    private func titled(_ title: String, @ViewBuilder cell: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulsePalette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            cell()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueKind: KeypadField.Kind {
        exercise.tracksDuration ? .duration : .reps
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
                .font(PulseFont.value(.headline))
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
            isProposed: Self.isProposed(kind, in: set), isFocused: model.focus == field(kind), width: width(weightWidth),
            label: Self.weightSpokenTitle(for: exercise.loadKind), hint: keypadHint,
            identifier: LiveSessionIdentifiers.weight(exercise: exerciseIndex, set: index)
        ) { model.focus(field(kind)); rpeSet = nil }
    }

    private var valueCell: some View {
        let kind = valueKind
        let saved = exercise.tracksDuration ? set.durationSeconds : set.reps
        return ValueCell(
            text: text(for: kind, saved: saved.map(String.init) ?? "\u{2013}"), isEmpty: saved == nil,
            isProposed: Self.isProposed(kind, in: set), isFocused: model.focus == field(kind), width: width(valueWidth),
            label: exercise.tracksDuration ? String(localized: "Secondes", bundle: .module)
                : String(localized: "Répétitions", bundle: .module), hint: keypadHint,
            identifier: LiveSessionIdentifiers.reps(exercise: exerciseIndex, set: index)
        ) { model.focus(field(kind)); rpeSet = nil }
    }

    private var rpeCell: some View {
        ValueCell(
            text: set.rpe.map { PulseFormat.decimal($0, maxFractionDigits: 1) } ?? "\u{2013}", isEmpty: set.rpe == nil,
            isProposed: false, isFocused: rpeSet == set.id, width: width(rpeWidth), label: String(localized: "RPE", bundle: .module),
            hint: String(localized: "Ouvre le choix du RPE", bundle: .module),
            identifier: LiveSessionIdentifiers.rpe(exercise: exerciseIndex, set: index)
        ) {
            model.focus(nil)
            rpeSet = rpeSet == set.id ? nil : set.id
        }
    }

    private var keypadHint: String {
        String(localized: "Ouvre le clavier", bundle: .module)
    }

    /// Une largeur qui suit le texte sur la ligne unique ; les cellules se partagent la ligne quand elle passe sur deux lignes.
    private func width(_ scaled: CGFloat) -> CGFloat? {
        Self.usesStackedLayout(typeSize) ? nil : scaled
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
            // Validée : une coche pleine sur un disque menthe ; à faire : un cercle cerclé, estompé. Le glyphe change, pas que
            // la couleur.
            Image(systemName: isDone ? "checkmark" : "checkmark.circle")
                .font(isDone ? .title3.weight(.black) : .title2.weight(.regular))
                .foregroundStyle(isDone ? PulsePalette.liveBackground : PulsePalette.muted)
                .frame(width: Self.targetHeight, height: Self.targetHeight)
                .background(isDone ? PulsePalette.ok : PulsePalette.surface2, in: Circle())
                // Une série validée s'allume : la lueur menthe dit « fait » d'un coup d'œil, entre deux séries.
                .shadow(color: isDone ? PulsePalette.ok.opacity(0.55) : .clear, radius: 10)
                .scaleEffect(isDone ? 1 : 0.92)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: isDone)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.checkSpokenLabel(index: index, type: set.setType))
        .accessibilityValue(Self.checkSpokenValue(isDone: isDone))
        .accessibilityHint(isDone ? String(localized: "Annule la validation de la série", bundle: .module)
                            : String(localized: "Valide la série", bundle: .module))
        .accessibilityIdentifier(LiveSessionIdentifiers.check(exercise: exerciseIndex, set: index))
        // Le bandeau de repos est lu après toute la liste : on peut passer le repos depuis n'importe quelle coche.
        .accessibilityActions {
            if model.session.rest != nil {
                Button(String(localized: "Passer le repos", bundle: .module)) {
                    Task { await RestBanner.skipRest(on: model) }
                }
            }
        }
    }
}

/// Une valeur touchable. Proposée par Pulse : grise dans un cadre pointillé, comme une suggestion ; saisie : à l'encre pleine
/// dans un cadre net ; vide : estompée. En noir et blanc, c'est le cadre et le gris qui font la différence, pas la couleur.
private struct ValueCell: View {
    let text: String
    let isEmpty: Bool
    let isProposed: Bool
    let isFocused: Bool
    let width: CGFloat?
    let label: String
    let hint: String
    let identifier: String
    let action: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        Button(action: action) {
            Text(text)
                .font(PulseFont.value(.title2, weight: .bold))
                .foregroundStyle(isEmpty ? PulsePalette.muted : (isProposed ? PulsePalette.text2 : PulsePalette.text))
                .pulseNumericTransition(value: Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: width)
                .frame(maxWidth: width == nil ? .infinity : nil, minHeight: LiveSetRow.targetHeight)
                .background(isFocused ? PulsePalette.surface2 : PulsePalette.surface, in: shape)
                .overlay(shape.strokeBorder(isFocused ? accent : PulsePalette.ink.opacity(isProposed ? 0.3 : 0.12),
                                            style: StrokeStyle(lineWidth: isFocused ? 2 : 1, dash: isProposed && !isFocused ? [3, 3] : [])))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(LiveSetRow.cellSpokenValue(text: text, isEmpty: isEmpty, isProposed: isProposed))
        .accessibilityHint(hint)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous)
    }
}
