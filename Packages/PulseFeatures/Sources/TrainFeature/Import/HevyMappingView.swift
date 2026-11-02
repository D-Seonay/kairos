import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La correspondance des noms de Hevy avec les exercices de Pulse (spec M4 §13.3) : « Correspondances sûres », « À choisir » et
/// « Ignorés », triés par nombre de séances. Chaque ligne a toujours un choix ; toucher une ligne ouvre un menu : un exercice de la
/// bibliothèque, un exercice perso à créer (formulaire pré-rempli) ou ignorer.
struct HevyMappingView: View {
    let model: HevyImportModel
    @State private var menuName: String?
    @State private var sheet: MappingSheet?

    private enum MappingSheet: Identifiable {
        case library(String)
        case create(String)

        var id: String {
            switch self {
            case .library(let name): "library." + name
            case .create(let name): "create." + name
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Button(String(localized: "Retour au résumé", bundle: .module)) { model.showSummary() }
                    .buttonStyle(PulseDesignSystem.LinkButtonStyle())
                intro
                section(String(localized: "Correspondances sûres", bundle: .module), model.sureNames)
                section(String(localized: "À choisir", bundle: .module), model.toChooseNames)
                section(String(localized: "Ignorés", bundle: .module), model.ignoredNames)
            }
            .padding(PulseMetrics.spacing)
        }
        .safeAreaInset(edge: .bottom) { importBar }
        .confirmationDialog(menuName ?? "", isPresented: menuBinding, titleVisibility: .visible, presenting: menuName) { name in
            menu(for: name)
        }
        .sheet(item: $sheet) { sheet in
            NavigationStack { sheetContent(sheet) }
        }
    }

    // MARK: - Contenu

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Associe tes exercices", bundle: .module))
                .font(.title2.weight(.bold))
                .foregroundStyle(PulsePalette.text)
                .accessibilityAddTraits(.isHeader)
            Text(String(localized: "Chaque exercice de Hevy a déjà un choix. Touche une ligne pour le changer.", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
            if model.unresolvedCount > 0 {
                Text(String(localized: "\(model.unresolvedCount) à vérifier : Pulse a deviné leur type.", bundle: .module))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulsePalette.warn)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ names: [HevyNameSummary]) -> some View {
        if !names.isEmpty {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PulsePalette.text)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)
            ForEach(names) { summary in
                HevyMappingRow(summary: summary, choiceLabel: model.label(for: summary.name),
                               isIgnored: model.choices[summary.name] == .ignore, needsReview: model.needsReview(summary.name)) {
                    menuName = summary.name
                }
            }
        }
    }

    private var importBar: some View {
        Button(importTitle) { Task { await model.start() } }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.canImport)
            .padding(PulseMetrics.spacing)
            .background(.bar)
            .accessibilityIdentifier(TrainIdentifiers.hevyImportStart)
    }

    private var importTitle: String {
        let count = model.preview?.newWorkouts.count ?? 0
        return String(localized: "Importer \(count) séances", bundle: .module)
    }

    // MARK: - Menu et feuilles

    private var menuBinding: Binding<Bool> {
        Binding(get: { menuName != nil }, set: { if !$0 { menuName = nil } })
    }

    @ViewBuilder
    private func menu(for name: String) -> some View {
        Button(String(localized: "Choisir un exercice Pulse", bundle: .module)) { sheet = .library(name) }
        Button(String(localized: "Créer un exercice perso", bundle: .module)) {
            model.markReviewed(name)
            sheet = .create(name)
        }
        if model.choices[name] != .ignore {
            Button(String(localized: "Ignorer", bundle: .module), role: .destructive) { model.choose(.ignore, for: name) }
        }
        Button(String(localized: "Reprendre la proposition", bundle: .module)) { model.restoreProposal(for: name) }
        Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
    }

    @ViewBuilder
    private func sheetContent(_ sheet: MappingSheet) -> some View {
        switch sheet {
        case .library(let name):
            LibraryView(model: model.libraryModel()) { references in
                self.sheet = nil
                guard let reference = references.first else { return }
                Task { await model.choose(reference: reference, for: name) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { self.sheet = nil }
                }
            }
        case .create(let name):
            CustomExerciseForm(model: model.customExerciseModel(for: name)) { exercise in
                model.didCreate(exercise, for: name)
            }
        }
    }
}
