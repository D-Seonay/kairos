import PulseDesignSystem
import SwiftUI
import TrainFeature

/// « Importer » dans Mes données, à côté de l'export : le même parcours d'import Hevy que l'onglet Séance.
struct HevyImportSection: View {
    let train: TrainEnvironment

    var body: some View {
        Section {
            NavigationLink {
                HevyImportDestination(train: train)
            } label: {
                Label(String(localized: "Importer depuis Hevy", bundle: .module), systemImage: "square.and.arrow.down")
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier(ProfileIdentifiers.hevyImport)
        } header: {
            Text(String(localized: "Importer", bundle: .module))
        } footer: {
            Text(String(localized: "Ton historique de séances, depuis un export CSV de Hevy.", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }
}

/// Le parcours d'import, qui revient à Mes données une fois terminé.
private struct HevyImportDestination: View {
    let train: TrainEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HevyImportFlow(model: HevyImportModel(environment: train), onFinish: { dismiss() })
    }
}
