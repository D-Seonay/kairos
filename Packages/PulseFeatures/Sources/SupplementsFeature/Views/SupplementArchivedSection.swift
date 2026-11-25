import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// « Archivés » : les compléments archivés, au bas de l'écran Compléments, chacun avec « Désarchiver » qui le remet dans la
/// liste et replanifie ses rappels. L'écran ne la montre que s'il y a au moins un complément archivé.
struct SupplementArchivedSection: View {
    let model: SupplementsModel
    /// Le complément en cours de désarchivage : une deuxième touche attend la première.
    @State private var restoring: UUID?

    var body: some View {
        VStack(spacing: 8) {
            PulseSectionHeader(String(localized: "Archivés", bundle: .module))
            ForEach(model.overview.archived) { supplement in
                PulseRow(systemImage: "archivebox", title: supplement.name, detail: SupplementText.dose(of: supplement)) {
                    Button(String(localized: "Désarchiver", bundle: .module)) { restore(supplement) }
                        .buttonStyle(PillButtonStyle())
                        .disabled(restoring != nil)
                        .accessibilityLabel(String(localized: "Désarchiver \(supplement.name)", bundle: .module))
                        .accessibilityIdentifier(SupplementsIdentifiers.unarchive(supplement.name))
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func restore(_ supplement: Supplement) {
        guard restoring == nil else { return }
        restoring = supplement.id
        Task {
            await model.unarchive(supplement)
            restoring = nil
        }
    }
}
