import PulseDesignSystem
import PulseServices
import SwiftUI

/// Le formulaire de « Saisir une séance passée » (spec M4 §19.4) : date, heure de début, durée, routine ou séance vide. À
/// présenter dans une `NavigationStack` : il fournit « Annuler » et « Saisir les séries », rend la séance à saisir à `onStart`,
/// puis se ferme.
public struct PastSessionForm: View {
    private let model: TrainModel
    private let onStart: (SessionLaunch) -> Void
    @State private var draft: PastSessionDraft
    @Environment(\.dismiss) private var dismiss

    public init(model: TrainModel, onStart: @escaping (SessionLaunch) -> Void) {
        self.model = model
        self.onStart = onStart
        _draft = State(initialValue: model.initialPastDraft())
    }

    public var body: some View {
        let problem = model.pastProblem(draft)
        Form {
            Section(String(localized: "Quand", bundle: .module)) {
                DatePicker(String(localized: "Date", bundle: .module), selection: $draft.day, in: ...model.now,
                           displayedComponents: .date)
                    .frame(minHeight: 44)
                DatePicker(String(localized: "Début", bundle: .module), selection: $draft.startTime,
                           displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
                Stepper(value: $draft.durationMinutes, in: PastSessionDraft.durationRange, step: PastSessionDraft.durationStep) {
                    Text(String(localized: "Durée : \(PulseFormat.duration(minutes: draft.durationMinutes))", bundle: .module))
                }
                .frame(minHeight: 44)
            }
            .listRowBackground(PulsePalette.surface)
            Section {
                Picker(String(localized: "Séance", bundle: .module), selection: $draft.routineID) {
                    Text(String(localized: "Séance vide", bundle: .module)).tag(UUID?.none)
                    ForEach(model.routines.filter { $0.day.kind == .strength }) { routine in
                        Text(routine.day.name).tag(UUID?.some(routine.day.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
            } footer: {
                Text(String(localized: """
                    Les charges proposées viennent de tes séances d'avant cette date. Pas de chrono ni de notification : tu \
                    coches ce que tu as fait.
                    """, bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            if let problem {
                Section {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(String(localized: "Séance passée", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module)) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Saisir les séries", bundle: .module), action: start)
                    .disabled(problem != nil)
                    .accessibilityIdentifier(TrainIdentifiers.pastSessionStart)
            }
        }
    }

    private func start() {
        guard let launch = model.pastLaunch(draft) else { return }
        onStart(launch)
        dismiss()
    }
}

#if DEBUG
/// Prépare l'onglet de l'aperçu (programme PPL), puis ouvre le formulaire sur ses routines.
private struct PastSessionFormPreview: View {
    @State private var model: TrainModel?

    var body: some View {
        NavigationStack {
            if let model {
                PastSessionForm(model: model) { _ in }
            } else {
                ProgressView()
            }
        }
        .task {
            let model = await TrainPreviewSupport.model(now: TrainPreviewSupport.date(day: 2, hour: 9))
            await model.refresh()
            self.model = model
        }
    }
}

#Preview("Séance passée") {
    PastSessionFormPreview()
}
#endif
