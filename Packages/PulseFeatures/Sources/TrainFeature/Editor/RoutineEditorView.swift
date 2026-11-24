import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'éditeur d'une routine (spec M4 §11.2) : son nom, la durée estimée, puis ses exercices, réordonnables, chacun avec ses
/// réglages. Les modifications forment un brouillon, enregistré par « Enregistrer » et abandonné, après confirmation, à la sortie.
/// À présenter dans une pile de navigation : l'écran fournit lui-même « Annuler » et « Enregistrer » et se ferme seul.
public struct RoutineEditorView: View {
    @State private var model: RoutineEditorModel
    @State private var expanded: UUID?
    @State private var isReordering = false
    @State private var isPicking = false
    @State private var confirmsDiscard = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    /// Vrai quand l'aperçu veut le premier exercice déplié à l'ouverture.
    private var expandsFirstExercise = false
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    /// La même vue, avec son premier exercice déplié : pour les aperçus.
    func expandingFirstExercise(_ expands: Bool) -> RoutineEditorView {
        var copy = self
        copy.expandsFirstExercise = expands
        return copy
    }
    #endif

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: RoutineEditorModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if model.isMissing {
                Text(String(localized: "Cette routine est introuvable ou ne peut pas être modifiée ici.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                    .padding(PulseMetrics.spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if model.hasLoaded {
                list
            } else if let message = model.errorMessage {
                loadFailure(message)
            } else {
                ProgressView()
                    .accessibilityLabel(String(localized: "Chargement de la routine", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PulsePalette.background)
        .navigationTitle(model.day.name.isEmpty ? String(localized: "Routine", bundle: .module) : model.day.name)
        .pulseInlineTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module), action: cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) { Task { await save() } }
                    .disabled(!model.canSave || isSaving)
                    .accessibilityIdentifier(TrainIdentifiers.routineSave)
            }
        }
        .confirmationDialog(String(localized: "Abandonner les modifications ?", bundle: .module), isPresented: $confirmsDiscard,
                            titleVisibility: .visible) {
            Button(String(localized: "Abandonner", bundle: .module), role: .destructive) { dismiss() }
            Button(String(localized: "Continuer à modifier", bundle: .module), role: .cancel) {}
        }
        .sheet(isPresented: $isPicking) {
            NavigationStack {
                LibraryView(model: model.libraryModel(), onPick: pick)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Annuler", bundle: .module)) { isPicking = false }
                        }
                    }
            }
        }
        .pulseAnnounceError(errorMessage ?? model.errorMessage)
        .task {
            await model.load()
            if expandsFirstExercise { expanded = model.day.exercises.first?.id }
        }
    }

    /// La lecture a échoué : le message et de quoi réessayer, plutôt qu'un indicateur sans fin.
    private func loadFailure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PulsePalette.bad)
                .multilineTextAlignment(.center)
            Button(String(localized: "Réessayer", bundle: .module)) { Task { await model.load() } }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            Section {
                TextField(String(localized: "Nom de la routine", bundle: .module),
                          text: Binding(get: { model.day.name }, set: { model.rename($0) }))
                    .frame(minHeight: 44)
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityLabel(spokenSummary)
            }
            .listRowBackground(PulsePalette.surface)
            Section {
                ForEach(Array(model.day.exercises.enumerated()), id: \.element.id) { index, exercise in
                    RoutineExerciseEditor(model: model, index: index, isExpanded: expanded == exercise.id && !isReordering) {
                        expanded = expanded == exercise.id ? nil : exercise.id
                    }
                    .accessibilityAction(named: String(localized: "Monter", bundle: .module)) { move(index, by: -1) }
                    .accessibilityAction(named: String(localized: "Descendre", bundle: .module)) { move(index, by: 1) }
                }
                .onMove { model.move(fromOffsets: $0, toOffset: $1) }
                addButton
            } header: {
                header
            }
            .listRowBackground(PulsePalette.surface)
            if let message = errorMessage ?? model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .reordering(isReordering)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "Exercices", bundle: .module))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if model.day.exercises.count > 1 {
                Button(isReordering ? String(localized: "OK", bundle: .module) : String(localized: "Réordonner", bundle: .module)) {
                    isReordering.toggle()
                }
                .textCase(nil)
                .accessibilityLabel(isReordering ? String(localized: "Terminer le réordonnancement", bundle: .module)
                                        : String(localized: "Réordonner les exercices", bundle: .module))
                .frame(minHeight: 44)
            }
        }
    }

    private var addButton: some View {
        Button { isPicking = true } label: {
            Label(String(localized: "Ajouter des exercices", bundle: .module), systemImage: "plus")
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier(TrainIdentifiers.routineAddExercises)
    }

    /// « 5 exercices · ~ 55 min ».
    private var summary: String {
        TrainText.editorSummary(exerciseCount: model.day.exercises.count, estimatedMinutes: model.estimatedMinutes)
    }

    /// « 5 exercices, environ 55 minutes ».
    private var spokenSummary: String {
        TrainText.editorSummarySpoken(exerciseCount: model.day.exercises.count, estimatedMinutes: model.estimatedMinutes)
    }

    // MARK: - Actions

    private func cancel() {
        if model.hasChanges {
            confirmsDiscard = true
        } else {
            dismiss()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await model.save()
            dismiss()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer la routine.", bundle: .module)
        }
    }

    /// Ajoute les exercices choisis après avoir relu ceux de l'utilisateur, au cas où l'un vienne d'être créé.
    private func pick(_ references: [ExerciseReference]) {
        isPicking = false
        Task {
            try? await model.refreshReferences()
            model.add(references)
        }
    }

    /// Déplace l'exercice d'un cran, pour VoiceOver.
    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard model.day.exercises.indices.contains(target) else { return }
        model.move(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}

private extension View {
    /// Le mode « Réordonner » : les poignées de déplacement apparaissent sur iOS ; sur Mac, les lignes se déplacent sans mode.
    func reordering(_ isActive: Bool) -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(isActive ? .active : .inactive))
        #else
        self
        #endif
    }
}
