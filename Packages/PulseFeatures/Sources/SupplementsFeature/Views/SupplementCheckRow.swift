import PulseDesignSystem
import PulseServices
import SwiftUI

/// Une ligne cochable : nom, dose et heure prévue, et la coche. Toucher le texte appelle `onOpen` (modifier), toucher la coche
/// appelle `onToggle`.
public struct SupplementCheckRow: View {
    private let item: SupplementDueItem
    private let onToggle: () -> Void
    private let onOpen: (() -> Void)?
    private let onArchive: (() -> Void)?

    public init(item: SupplementDueItem, onToggle: @escaping () -> Void, onOpen: (() -> Void)? = nil,
                onArchive: (() -> Void)? = nil) {
        self.item = item
        self.onToggle = onToggle
        self.onOpen = onOpen
        self.onArchive = onArchive
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let onOpen {
                openButton(onOpen)
            } else {
                label
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SupplementsModel.rowSpoken(item))
            }
            // La coche est un interrupteur : son nom ne change pas, son état se lit dans la valeur.
            Button(action: onToggle) {
                Image(systemName: item.isTaken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isTaken ? PulsePalette.text : PulsePalette.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(PressableButtonStyle())
            .sensoryFeedback(.success, trigger: item.isTaken) { _, taken in taken }
            .accessibilityLabel(item.supplement.name)
            .accessibilityValue(SupplementsModel.takenValue(item.isTaken))
            .accessibilityAddTraits(.isToggle)
            .accessibilityIdentifier(SupplementsIdentifiers.check(item.supplement.name))
        }
    }

    /// La ligne qui ouvre le formulaire ; « Archiver » est une action nommée, comme le menu contextuel.
    @ViewBuilder
    private func openButton(_ onOpen: @escaping () -> Void) -> some View {
        let button = Button(action: onOpen) { label }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(SupplementsModel.rowSpoken(item))
            .accessibilityHint(String(localized: "Modifie le complément", bundle: .module))
        if let onArchive {
            button.accessibilityAction(named: String(localized: "Archiver", bundle: .module), onArchive)
        } else {
            button
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            IconChip(systemName: "pills", size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.supplement.name)
                    .font(.headline)
                    .foregroundStyle(PulsePalette.text)
                    .strikethrough(item.isTaken, color: PulsePalette.muted)
                Text(SupplementsModel.detail(item))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if item.supplement.isLowOnStock {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(PulsePalette.bad)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// Les compléments « autour de la séance » du récap (spec M5 §10), cochables. Le récap lit le modèle avec son bilan, et cache
/// la liste quand elle est vide.
public struct SupplementsWorkoutChecklist: View {
    private let model: SupplementsModel

    public init(model: SupplementsModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 4) {
            ForEach(model.overview.workoutItems) { item in
                SupplementCheckRow(item: item) { Task { await model.toggle(item) } }
            }
        }
    }
}
