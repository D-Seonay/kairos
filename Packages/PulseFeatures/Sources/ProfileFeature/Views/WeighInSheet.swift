import PulseDesignSystem
import SwiftUI

/// La feuille d'une pesée : le poids au clavier décimal et la date, jamais après maintenant. À présenter dans une
/// `NavigationStack` : elle fournit « Annuler » et « Enregistrer ». Un poids refusé laisse la feuille ouverte avec son message.
struct WeighInSheet: View {
    let model: WeightModel
    @FocusState private var isWeightFocused: Bool

    var body: some View {
        let now = model.environment.now()
        Form {
            Section {
                HStack(spacing: 8) {
                    TextField(ProfileText.weightFieldLabel, text: weightText, prompt: Text(verbatim: "78,4"))
                        .pulseNumericKeyboard()
                        .focused($isWeightFocused)
                        .font(PulseFont.value(.title2))
                        .foregroundStyle(PulsePalette.text)
                    Text(String(localized: "kg", bundle: .module))
                        .font(.body)
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                // Toute la ligne est tactile, pas seulement la hauteur du texte.
                .contentShape(Rectangle())
                .onTapGesture { isWeightFocused = true }
            } header: {
                Text(String(localized: "Poids en kilos", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            Section {
                DatePicker(String(localized: "Date", bundle: .module), selection: date, in: ...now,
                           displayedComponents: [.date, .hourAndMinute])
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .environment(\.calendar, model.environment.calendar)
                    .environment(\.timeZone, model.environment.calendar.timeZone)
                    .frame(minHeight: 44)
            }
            .listRowBackground(PulsePalette.surface)
            if let message = model.editorError {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(PulsePalette.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(isEditing
            ? String(localized: "Modifier la pesée", bundle: .module)
            : String(localized: "Nouvelle pesée", bundle: .module))
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module), action: model.closeEditor)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) {
                    Task { await model.save() }
                }
                .disabled(model.isSaving)
            }
        }
        .pulseAnnounceOnce(model.editorError, id: model.editorFailureCount, isError: true)
        .presentationDetents([.medium, .large])
        .onAppear { isWeightFocused = !isEditing }
    }

    private var isEditing: Bool { model.editor?.measurementID != nil }

    private var weightText: Binding<String> {
        Binding(get: { model.editor?.weightText ?? "" }, set: { model.editor?.weightText = $0 })
    }

    private var date: Binding<Date> {
        Binding(get: { model.editor?.date ?? model.environment.now() }, set: { model.editor?.date = $0 })
    }
}
