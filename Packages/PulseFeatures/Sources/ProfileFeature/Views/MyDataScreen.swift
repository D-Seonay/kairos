import PulseDesignSystem
import PulseDomain
import SwiftUI

/// L'écran Mes données (spec M7 §16), poussé depuis la page Profil : ce que le téléphone stocke et l'état d'iCloud, les exports
/// par la feuille de partage, la suppression totale (la confirmation vient de l'app), les liens et, en DEBUG, les outils.
struct MyDataScreen: View {
    @State private var model: MyDataModel
    @State private var showsErase = false
    @State private var exporting: ExportFormat?
    let environment: ProfileEnvironment
    let screens: ProfileAppScreens
    /// Part une fois tout supprimé : l'app revient à l'onboarding.
    let onErased: () async -> Void

    init(environment: ProfileEnvironment, screens: ProfileAppScreens, onErased: @escaping () async -> Void) {
        _model = State(initialValue: MyDataModel(environment: environment))
        self.environment = environment
        self.screens = screens
        self.onErased = onErased
    }

    var body: some View {
        List {
            if let message = model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(PulsePalette.surface)
            }
            phoneSection
            exportSection
            eraseSection
            linksSection
            if let dataDebug = screens.dataDebug {
                developmentSection(dataDebug)
            }
        }
        .scrollContentBackground(.hidden)
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Mes données", bundle: .module))
        .pulseInlineTitle()
        .sheet(isPresented: $showsErase) { screens.eraseConfirmation(onErased) }
        .task { await model.refresh() }
        .pulseAnnounceOnce(model.errorMessage, id: model.failureCount, isError: true)
        // Un export tourne puis son bouton de partage surgit : début et fin sont annoncés.
        .onChange(of: model.isBusy) { _, isBusy in
            if isBusy { PulseAnnouncement.post(ProfileText.exportStarted) }
        }
        .onChange(of: model.shareURL) { _, url in
            if url != nil { PulseAnnouncement.post(ProfileText.exportReady) }
        }
    }

    // MARK: Sur ce téléphone

    private var phoneSection: some View {
        Section {
            countRow(String(localized: "Séances", bundle: .module), .workoutSessions)
            countRow(String(localized: "Scores", bundle: .module), .dailyRecoveries)
            countRow(String(localized: "Pesées", bundle: .module), .bodyMeasurements)
            countRow(String(localized: "Compléments", bundle: .module), .supplements)
            countRow(String(localized: "Échantillons Apple Santé", bundle: .module), .cachedHealthSamples)
            Text(MyDataModel.cloudText(model.cloudStatus))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
        } header: {
            Text(String(localized: "Sur ce téléphone", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Avant la première lecture « Pas encore lu » ; une table qui n'a pas pu être comptée « — », jamais un zéro inventé.
    private func countRow(_ title: String, _ table: StoreTable) -> some View {
        LabeledContent(title, value: MyDataModel.countText(model.counts[table], hasRefreshed: model.hasRefreshed))
            .foregroundStyle(PulsePalette.text)
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(MyDataModel.countSpoken(model.counts[table], hasRefreshed: model.hasRefreshed))
    }

    // MARK: Exporter

    /// Le format de l'export lancé : seul son bouton tourne. ShareLink ne se déclenche pas tout seul : « Partager l'export »
    /// apparaît sous les boutons une fois le fichier prêt.
    private enum ExportFormat {
        case json
        case csv
    }

    private var exportSection: some View {
        Section {
            Button {
                exporting = .json
                Task { await model.exportJSON() }
            } label: {
                exportLabel(String(localized: "Tout en JSON", bundle: .module), format: .json)
            }
            Button {
                exporting = .csv
                Task { await model.exportCSV() }
            } label: {
                exportLabel(String(localized: "Tout en CSV (zip)", bundle: .module), format: .csv)
            }
            if let url = model.shareURL {
                ShareLink(item: url) {
                    Label(String(localized: "Partager l'export", bundle: .module), systemImage: "square.and.arrow.up")
                        .foregroundStyle(PulsePalette.text)
                }
                .frame(minHeight: 44)
            }
        } header: {
            Text(String(localized: "Exporter", bundle: .module))
        } footer: {
            Text(ProfileText.photosExportNote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(model.isBusy)
        .listRowBackground(PulsePalette.surface)
    }

    private func exportLabel(_ title: String, format: ExportFormat) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(PulsePalette.text)
            Spacer(minLength: 8)
            if model.isBusy && exporting == format {
                ProgressView()
                    .accessibilityLabel(ProfileText.exportStarted)
            }
        }
        .frame(minHeight: 44)
    }

    // MARK: Supprimer

    private var eraseSection: some View {
        Section {
            Button(role: .destructive) {
                showsErase = true
            } label: {
                Text(String(localized: "Tout supprimer", bundle: .module))
                    .foregroundStyle(PulsePalette.bad)
                    .frame(minHeight: 44, alignment: .leading)
            }
        } header: {
            Text(String(localized: "Supprimer", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    // MARK: Liens

    private var linksSection: some View {
        Section {
            if let url = environment.privacyPolicyURL {
                Link(destination: url) {
                    HStack {
                        Text(String(localized: "Politique de confidentialité", bundle: .module))
                            .foregroundStyle(PulsePalette.text)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
            }
            NavigationLink {
                LicensesView()
            } label: {
                Text(String(localized: "Licences", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "Liens", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    // MARK: Outils de développement

    private func developmentSection(_ dataDebug: @escaping () -> AnyView) -> some View {
        Section {
            NavigationLink {
                dataDebug()
            } label: {
                Text(String(localized: "Données (debug)", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "Outils de développement", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }
}

#if DEBUG
/// Prépare l'environnement de l'aperçu puis pousse l'écran ; `privacyPolicyURL` montre la ligne de la politique.
private struct MyDataPreviewHost: View {
    var privacyPolicyURL: URL?
    var withDebug = true
    @State private var environment: ProfileEnvironment?

    var body: some View {
        NavigationStack {
            if let environment {
                MyDataScreen(environment: environment, screens: screens) {}
            } else {
                ProgressView()
            }
        }
        .task {
            var environment = await ProfilePreviewSupport.environment()
            environment.privacyPolicyURL = privacyPolicyURL
            self.environment = environment
        }
        .preferredColorScheme(.light)
    }

    private var screens: ProfileAppScreens {
        var screens = ProfilePreviewSupport.screens
        if !withDebug { screens.dataDebug = nil }
        return screens
    }
}

#Preview("Mes données") {
    MyDataPreviewHost(privacyPolicyURL: URL(string: "https://example.com/confidentialite"))
}

#Preview("Mes données, très grand texte") {
    MyDataPreviewHost(privacyPolicyURL: URL(string: "https://example.com/confidentialite"))
        .dynamicTypeSize(.accessibility3)
}

#Preview("Mes données, Release") {
    MyDataPreviewHost(withDebug: false)
}
#endif
