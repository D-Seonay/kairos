import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// L'éditeur d'une course du programme : son type (sortie facile, fractionné, sortie longue) et son objectif, une durée, une
/// distance ou rien. Comme l'éditeur d'une routine, il travaille sur un brouillon, enregistré par « Enregistrer » et abandonné,
/// après confirmation, à la sortie. À présenter dans une pile de navigation : l'écran fournit « Annuler » et « Enregistrer ».
public struct RunDayEditorView: View {
    @State private var model: RunDayEditorModel
    @State private var confirmsDiscard = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    /// Le modèle est gardé par l'écran : le premier reçu l'emporte, comme le veut `@State`.
    public init(model: RunDayEditorModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            if model.isMissing {
                Text(String(localized: "Cette course est introuvable ou ne peut pas être modifiée ici.", bundle: .module))
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
                    .accessibilityLabel(String(localized: "Chargement de la course", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(PulsePalette.background)
        .navigationTitle(model.day.name.isEmpty ? String(localized: "Course", bundle: .module) : model.day.name)
        .pulseInlineTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module), action: cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) { Task { await save() } }
                    .disabled(!model.hasChanges || isSaving)
                    .accessibilityIdentifier(TrainIdentifiers.runDaySave)
            }
        }
        .confirmationDialog(String(localized: "Abandonner les modifications ?", bundle: .module), isPresented: $confirmsDiscard,
                            titleVisibility: .visible) {
            Button(String(localized: "Abandonner", bundle: .module), role: .destructive) { dismiss() }
            Button(String(localized: "Continuer à modifier", bundle: .module), role: .cancel) {}
        }
        .pulseAnnounceError(errorMessage ?? model.errorMessage)
        .task { await model.load() }
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
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            Section {
                // Une ligne par type, cochée : le choix reste lisible aux grandes tailles de texte.
                Picker(String(localized: "Type de course", bundle: .module),
                       selection: Binding(get: { model.type }, set: { model.setType($0) })) {
                    ForEach(RunType.allCases, id: \.self) { type in
                        Text(type.localizedName)
                            .foregroundStyle(PulsePalette.text)
                            .frame(minHeight: 44)
                            .tag(type)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier(TrainIdentifiers.runDayType)
            } header: {
                Text(String(localized: "Type de course", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            Section {
                Picker(selection: Binding(get: { model.goalKind }, set: { model.setGoalKind($0) })) {
                    ForEach(RunGoalKind.allCases, id: \.self) { kind in
                        Text(kind.trainName).tag(kind)
                    }
                } label: {
                    Text(String(localized: "Objectif", bundle: .module))
                        .foregroundStyle(PulsePalette.text)
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier(TrainIdentifiers.runDayGoal)
                goalStepper
            } header: {
                Text(String(localized: "Objectif", bundle: .module))
            } footer: {
                Text(String(localized: "Une durée ou une distance, au choix. Sans objectif, tu cours comme tu le sens.",
                            bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
        }
        .scrollContentBackground(.hidden)
    }

    /// Le pas à pas de la durée ou de la distance ; rien sans objectif.
    @ViewBuilder
    private var goalStepper: some View {
        let value = TrainText.runGoalValue(model.goal) ?? ""
        let spoken = TrainText.runGoalSpoken(model.goal) ?? ""
        switch model.goal {
        case .none:
            EmptyView()
        case .minutes(let minutes):
            Stepper(value: Binding(get: { minutes }, set: { model.setMinutes($0) }), in: RunDayRules.minutes,
                    step: RunDayRules.minutesStep) {
                Text(String(localized: "Durée : \(value)", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .accessibilityLabel(String(localized: "Durée", bundle: .module))
            .accessibilityValue(spoken)
            .frame(minHeight: 44)
        case .kilometres(let kilometres):
            Stepper(value: Binding(get: { kilometres }, set: { model.setKilometres($0) }), in: RunDayRules.kilometres,
                    step: RunDayRules.kilometresStep) {
                Text(String(localized: "Distance : \(value)", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .accessibilityLabel(String(localized: "Distance", bundle: .module))
            .accessibilityValue(spoken)
            .frame(minHeight: 44)
        }
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
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer la course.", bundle: .module)
        }
    }
}

extension RunGoalKind {
    /// « Aucun », « Durée », « Distance » : le choix de l'objectif.
    var trainName: String {
        switch self {
        case .none: String(localized: "Aucun", bundle: .module)
        case .duration: String(localized: "Durée", bundle: .module)
        case .distance: String(localized: "Distance", bundle: .module)
        }
    }
}

#if DEBUG
#Preview("Course : sortie facile") {
    RunDayEditorPreviewHost()
}

#Preview("Course : sortie facile, accessibilité XL") {
    RunDayEditorPreviewHost()
        .dynamicTypeSize(.accessibility3)
}
#endif
