import PulseDesignSystem
import PulseServices
import SwiftUI

/// La carte Compléments de l'accueil (spec M5 §10) : « 2 sur 5 », la prochaine prise avec « Pris », l'alerte de stock. Le
/// titre ouvre l'écran Compléments par `onOpen`.
public struct SupplementsCard: View {
    private let model: SupplementsModel
    private let onOpen: () -> Void

    public init(model: SupplementsModel, onOpen: @escaping () -> Void) {
        self.model = model
        self.onOpen = onOpen
    }

    public var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onOpen) { header }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier(SupplementsIdentifiers.card)
                if model.overview.supplements.isEmpty {
                    Text(String(localized: "Ajoute ce que tu prends pour le cocher ici et recevoir un rappel.", bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                } else if let next = model.overview.next {
                    NextIntakeRow(item: next) { Task { await model.toggle(next) } }
                } else {
                    Text(model.overview.dueCount == 0 ? String(localized: "Rien de prévu aujourd'hui.", bundle: .module)
                         : String(localized: "Tout est pris pour aujourd'hui.", bundle: .module))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(String(localized: "Compléments", bundle: .module), systemImage: "pills")
                .pulseEyebrow(PulsePalette.text2)
            if !model.overview.lowStock.isEmpty {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(PulsePalette.bad)
                    .accessibilityLabel(String(localized: "Stock bas", bundle: .module))
            }
            Spacer(minLength: 8)
            if model.overview.dueCount > 0 {
                Text(model.countText)
                    .pulseEyebrow(PulsePalette.text)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 24)
                    .overlay(Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1))
            }
            RowChevron()
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
