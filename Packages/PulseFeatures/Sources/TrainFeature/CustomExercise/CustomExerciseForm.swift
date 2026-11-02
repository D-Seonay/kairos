import PulseContent
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le formulaire d'un exercice perso (spec M4 §10.3). À présenter dans une `NavigationStack` (feuille ou pile) : il fournit
/// « Annuler » et « Enregistrer », se ferme seul, puis prévient `onSaved` ou `onArchived`.
public struct CustomExerciseForm: View {
    @State private var model: CustomExerciseModel
    private let onSaved: (UserExercise) -> Void
    private let onArchived: () -> Void
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var confirmsArchive = false
    @Environment(\.dismiss) private var dismiss

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: CustomExerciseModel, onSaved: @escaping (UserExercise) -> Void = { _ in },
                onArchived: @escaping () -> Void = {}) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
        self.onArchived = onArchived
    }

    public var body: some View {
        Form {
            nameSection
            musclesSection
            movementSection
            settingsSection
            if model.isEditing {
                archiveSection
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(model.isEditing ? String(localized: "Modifier l'exercice", bundle: .module)
                            : String(localized: "Nouvel exercice", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module)) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) { Task { await save() } }
                    .disabled(!model.canSave || isWorking)
            }
        }
        .confirmationDialog(String(localized: "Archiver cet exercice ?", bundle: .module), isPresented: $confirmsArchive,
                            titleVisibility: .visible) {
            Button(String(localized: "Archiver", bundle: .module), role: .destructive) { Task { await archive() } }
            Button(String(localized: "Annuler", bundle: .module), role: .cancel) {}
        } message: {
            Text(String(localized: "Il ne sera plus proposé, mais tes anciennes séances le gardent.", bundle: .module))
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section(String(localized: "Nom", bundle: .module)) {
            TextField(String(localized: "Nom de l'exercice", bundle: .module), text: $model.name)
                .frame(minHeight: 44)
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var musclesSection: some View {
        Group {
            Section(String(localized: "Muscles", bundle: .module)) {
                MenuPicker(title: String(localized: "Muscle principal", bundle: .module), options: Muscle.allCases,
                           label: \.localizedName,
                           selection: Binding(get: { model.primaryMuscle }, set: { model.setPrimaryMuscle($0) }))
            }
            .listRowBackground(PulsePalette.surface)
            Section(String(localized: "Muscles secondaires", bundle: .module)) {
                MultiChoicePills(options: Muscle.allCases.filter { $0 != model.primaryMuscle }.map { ($0, $0.localizedName) },
                                 selection: $model.secondaryMuscles)
                    .padding(.vertical, 4)
            }
            .listRowBackground(PulsePalette.surface)
        }
    }

    private var movementSection: some View {
        Section(String(localized: "Mouvement", bundle: .module)) {
            MenuPicker(title: String(localized: "Matériel", bundle: .module), options: Equipment.allCases,
                       label: \.localizedName, selection: Binding(get: { model.equipment }, set: { model.setEquipment($0) }))
            MenuPicker(title: String(localized: "Plan de mouvement", bundle: .module), options: MovementPattern.allCases,
                       label: \.localizedName, selection: $model.pattern)
            MenuPicker(title: String(localized: "Région", bundle: .module), options: BodyRegion.allCases,
                       label: \.localizedName, selection: Binding(get: { model.region }, set: { model.setRegion($0) }))
            MenuPicker(title: String(localized: "Nature de la charge", bundle: .module), options: LoadKind.allCases,
                       label: \.localizedName, selection: $model.loadKind)
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var settingsSection: some View {
        Section(String(localized: "Réglages", bundle: .module)) {
            Toggle(String(localized: "Unilatéral", bundle: .module), isOn: $model.isUnilateral)
            Toggle(String(localized: "Polyarticulaire", bundle: .module), isOn: $model.isCompound)
            Toggle(String(localized: "Tenu en secondes", bundle: .module), isOn: $model.tracksDuration)
            Stepper(value: $model.incrementKg, in: 0.25...20, step: 0.25) {
                Text(String(localized: "Incrément : \(PulseFormat.decimal(model.incrementKg, maxFractionDigits: 2)) kg",
                            bundle: .module))
            }
            Stepper(value: $model.restSeconds, in: 15...600, step: 15) {
                Text(String(localized: "Repos : \(PulseFormat.restDuration(seconds: model.restSeconds))", bundle: .module))
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var archiveSection: some View {
        Section {
            Button(String(localized: "Archiver cet exercice", bundle: .module), role: .destructive) { confirmsArchive = true }
                .frame(minHeight: 44)
        }
        .listRowBackground(PulsePalette.surface)
    }

    // MARK: - Actions

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let saved = try await model.save()
            dismiss()
            onSaved(saved)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer l'exercice.", bundle: .module)
        }
    }

    private func archive() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await model.archive()
            dismiss()
            onArchived()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu archiver l'exercice.", bundle: .module)
        }
    }
}

/// Un choix dans un menu déroulant, sous son intitulé.
private struct MenuPicker<Value: Hashable>: View {
    let title: String
    let options: [Value]
    let label: KeyPath<Value, String>
    let selection: Binding<Value>

    var body: some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { Text($0[keyPath: label]).tag($0) }
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
    }
}
