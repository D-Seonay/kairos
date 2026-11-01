import PulseDomain
import SwiftUI

/// Onglet « Données » (spec M2 §8). Sans style : le design system arrive en M3.
struct DataDebugView: View {
    @State private var model: DataDebugModel
    @State private var showsErase = false

    init(model: DataDebugModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            List {
                contentSection
                storeSection
                actionsSection
            }
            .navigationTitle(String(localized: "Données"))
            .sheet(isPresented: $showsErase) { EraseConfirmationView(model: model) }
        }
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
    DataDebugView(model: DataDebugModel(dependencies: .preview()))
}
