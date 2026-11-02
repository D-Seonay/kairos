import PulseDesignSystem
import SwiftUI

/// L'historique (spec M4 §12) : les séances terminées et abandonnées par mois, séances Pulse et séances importées de Hevy mêlées ;
/// toucher une ligne ouvre son détail. En bas, « Supprimer toutes les séances importées de Hevy » annule un import raté.
/// À présenter dans la pile de l'onglet « Séance », qui ouvre le détail d'une séance.
public struct HistoryView: View {
    @State private var model: HistoryModel
    @State private var confirmsRemoval = false
    @State private var isRemoving = false
    @State private var errorMessage: String?

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: HistoryModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if model.hasLoaded {
                list
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Historique", bundle: .module))
        .pulseInlineTitle()
        .confirmationDialog(String(localized: "Supprimer les séances importées de Hevy ?", bundle: .module),
                            isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button(String(localized: "Tout supprimer", bundle: .module), role: .destructive) { Task { await removeImported() } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "Tes séances Pulse restent. Tes records sont recalculés.", bundle: .module))
        }
        .task { await model.load() }
    }

    private var list: some View {
        List {
            if let message = errorMessage ?? model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if model.months.isEmpty, model.errorMessage == nil {
                Section {
                    Text(String(localized: "Aucune séance pour l'instant. Tes séances terminées apparaîtront ici.", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
                .listRowBackground(PulsePalette.surface)
            }
            ForEach(model.months) { month in
                Section {
                    ForEach(month.sessions) { line in
                        NavigationLink(value: TrainDestination.session(line.id)) {
                            HistoryRow(line: line, dateText: model.dateText(line.date))
                        }
                        .accessibilityIdentifier(TrainIdentifiers.historyRowPrefix + line.id.uuidString)
                    }
                } header: {
                    Text(month.title)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if model.hasImportedSessions {
                removal
            }
        }
        .scrollContentBackground(.hidden)
        .refreshable { await model.load() }
    }

    private var removal: some View {
        Section {
            Button(role: .destructive) { confirmsRemoval = true } label: {
                Text(String(localized: "Supprimer toutes les séances importées de Hevy", bundle: .module))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(isRemoving)
            .accessibilityIdentifier(TrainIdentifiers.historyRemoveImported)
        } footer: {
            Text(String(localized: "Pour annuler un import raté.", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private func removeImported() async {
        isRemoving = true
        defer { isRemoving = false }
        do {
            _ = try await model.removeImported()
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu supprimer les séances importées.", bundle: .module)
        }
    }
}
