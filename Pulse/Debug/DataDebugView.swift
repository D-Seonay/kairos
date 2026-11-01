import PulseDomain
import SwiftUI

/// Écran de debug « Données » (spec M2 §8), ouvert depuis le profil. Sans style : le design system arrive en M3.
struct DataDebugView: View {
    @State private var model: DataDebugModel
    @State private var showsErase = false
    private let onErased: () async -> Void

    /// `onErased` est appelé après une suppression totale réussie.
    init(model: DataDebugModel, onErased: @escaping () async -> Void) {
        _model = State(initialValue: model)
        self.onErased = onErased
    }

    var body: some View {
        List {
            contentSection
            storeSection
            actionsSection
        }
        .navigationTitle(String(localized: "Données"))
        .sheet(isPresented: $showsErase) { EraseConfirmationView(model: model, onErased: onErased) }
        .task { await model.refresh() }
    }

    private var contentSection: some View {
        Section(String(localized: "Contenu")) {
            LabeledContent(String(localized: "Version du contenu"), value: model.contentVersion)
            NavigationLink(String(localized: "\(model.exerciseCount) exercices")) { ContentExercisesView(model: model) }
            NavigationLink(String(localized: "\(model.templateCount) modèles")) { ContentTemplatesView(model: model) }
        }
    }

    private var storeSection: some View {
        Section(String(localized: "Stockage")) {
            LabeledContent(String(localized: "Mode"), value: model.storeModeText)
            LabeledContent(String(localized: "iCloud"), value: DataDebugModel.text(for: model.cloudStatus))
            ForEach(StoreTable.allCases, id: \.self) { table in
                LabeledContent(table.fileName, value: "\(model.counts[table] ?? 0)")
                    .font(.footnote.monospacedDigit())
            }
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
        }
    }

    private var actionsSection: some View {
        Section(String(localized: "Actions")) {
            Button(String(localized: "Insérer des données d'exemple")) { Task { await model.seedSampleData() } }
            Button(String(localized: "Exporter en JSON")) { Task { await model.exportJSON() } }
            Button(String(localized: "Exporter en CSV")) { Task { await model.exportCSV() } }
            if let url = model.shareURL {
                ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up") }
            }
            Button(String(localized: "Tout supprimer"), role: .destructive) { showsErase = true }
            if model.didErase {
                Text(String(localized: "Toutes les données ont été supprimées")).foregroundStyle(.secondary)
            }
        }
        .disabled(model.isBusy)
    }
}

#Preview {
    NavigationStack {
        DataDebugView(model: DataDebugModel(dependencies: .preview())) {}
    }
}
