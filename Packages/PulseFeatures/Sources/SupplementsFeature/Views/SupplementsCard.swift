import PulseDesignSystem
import PulseServices
import SwiftUI

/// La carte Compléments de l'accueil (spec M5 §10) : « 2 sur 5 », la prochaine prise avec « Pris », l'alerte de stock. Le
/// titre ouvre l'écran Compléments par `onOpen`.
public struct SupplementsCard: View {
    private let model: SupplementsModel
    private let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

    /// Le titre, l'alerte de stock, le compte et le chevron sur une ligne ; aux tailles d'accessibilité, le titre au-dessus.
    private var header: some View {
        let title = Label(String(localized: "Compléments", bundle: .module), systemImage: "pills")
            .pulseEyebrow(PulsePalette.text2)
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    title
                    HStack(spacing: 8) {
                        stockAlert
                        countChip
                        Spacer(minLength: 8)
                        RowChevron()
                    }
                }
            } else {
                HStack(spacing: 8) {
                    title
                    stockAlert
                    Spacer(minLength: 8)
                    countChip
                    RowChevron()
                }
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var stockAlert: some View {
        if !model.overview.lowStock.isEmpty {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(PulsePalette.bad)
                .accessibilityLabel(String(localized: "Stock bas", bundle: .module))
        }
    }

    /// Le compte « 2 sur 5 », dit « 2 sur 5 pris ».
    @ViewBuilder
    private var countChip: some View {
        if model.overview.dueCount > 0 {
            Text(model.countText)
                .pulseEyebrow(PulsePalette.text)
                .padding(.horizontal, 10)
                .frame(minHeight: 24)
                .overlay(Capsule().strokeBorder(PulsePalette.ink.opacity(0.2), lineWidth: 1))
                .accessibilityLabel(SupplementsModel.summarySpoken(taken: model.overview.takenCount, due: model.overview.dueCount))
        }
    }
}
