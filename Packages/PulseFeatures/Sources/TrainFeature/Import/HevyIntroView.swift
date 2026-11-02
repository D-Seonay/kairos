import PulseDesignSystem
import SwiftUI
import UniformTypeIdentifiers

/// Où trouver l'export dans Hevy, puis le sélecteur de fichiers (`.csv`). Le fichier est lu ici, sur l'iPhone : le modèle reçoit
/// ses octets.
struct HevyIntroView: View {
    let model: HevyImportModel
    @State private var isPicking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PulseMetrics.spacing) {
                Text(String(localized: "Reprends ton historique", bundle: .module))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "Pulse lit l'export de tes séances Hevy et les ajoute à ton historique, avec tes records.",
                            bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                ObsidianCard {
                    VStack(alignment: .leading, spacing: 12) {
                        step(1, String(localized: "Dans Hevy, ouvre ton profil puis les réglages.", bundle: .module))
                        step(2, String(localized: "Choisis « Exporter les données » et garde le format CSV.", bundle: .module))
                        step(3, String(localized: "Enregistre le fichier dans l'app Fichiers, puis choisis-le ici.", bundle: .module))
                    }
                }
                Text(String(localized: "Le fichier est lu sur cet appareil : il n'est envoyé nulle part.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                Button(String(localized: "Choisir le fichier", bundle: .module)) { isPicking = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier(TrainIdentifiers.hevyImportPick)
            }
            .padding(PulseMetrics.spacing)
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.commaSeparatedText]) { result in
            Task { await open(result) }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(number))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulsePalette.text)
                .frame(width: 28, height: 28)
                .background(PulsePalette.surface2, in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Étape \(number) : \(text)", bundle: .module))
    }

    /// Lit le fichier choisi, avec l'accès à sa ressource à portée de sécurité pendant la lecture, puis l'analyse.
    private func open(_ result: Result<URL, any Error>) async {
        switch result {
        case .success(let url):
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? await Task.detached(operation: { try Data(contentsOf: url) }).value {
                await model.read(data)
            } else {
                model.readingFailed()
            }
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled { model.readingFailed() }
        }
    }
}
