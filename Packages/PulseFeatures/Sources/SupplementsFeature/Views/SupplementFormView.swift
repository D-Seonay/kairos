import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le formulaire d'un complément (spec M5 §10, maquette `supplement-new`) : suggestions, nom, forme, dose, moment, jours,
/// rappel, Apple Santé, stock. À présenter dans une `NavigationStack` : il fournit « Annuler » et « Enregistrer ». Un brouillon
/// modifié ne se perd ni d'un glissé ni d'« Annuler » sans confirmation ; un enregistrement raté s'affiche dans le formulaire.
struct SupplementFormView: View {
    let model: SupplementsModel
    let editing: Supplement?
    /// Le brouillon à l'ouverture : le formulaire est modifié dès que `draft` en diffère.
    @State private var initialDraft: SupplementDraft
    @State private var draft: SupplementDraft
    @State private var archiving: Supplement?
    @State private var confirmsDiscard = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: SupplementsModel, editing: Supplement?) {
        self.model = model
        self.editing = editing
        let initial = editing.map(SupplementDraft.init) ?? SupplementDraft()
        _initialDraft = State(initialValue: initial)
        _draft = State(initialValue: initial)
    }

    private var isDirty: Bool { draft != initialDraft }

    var body: some View {
        Form {
            if editing == nil { suggestions }
            identity
            moment
            Section {
                Toggle(String(localized: "Rappel", bundle: .module), isOn: $draft.reminder)
                    .frame(minHeight: 44)
            } footer: {
                Text(String(localized: "Une notification avec un bouton « Pris », même écran verrouillé.", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            health
            stock
            if let editing { archiveSection(editing) }
            if let problem = draft.problem, draft != SupplementDraft() {
                Section {
                    Text(problem).font(.footnote).foregroundStyle(PulsePalette.bad)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if let message = model.editorError {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(PulsePalette.surface)
            }
            Section {
            } footer: {
                Text(SupplementLabels.disclaimer)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulsePalette.background)
        .navigationTitle(editing == nil ? String(localized: "Nouveau complément", bundle: .module) : draft.name)
        .pulseInlineTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Annuler", bundle: .module)) {
                    if isDirty { confirmsDiscard = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Enregistrer", bundle: .module)) {
                    Task { _ = await model.save(draft, editing: editing) }
                }
                .disabled(draft.problem != nil || model.isSaving)
                .accessibilityIdentifier(SupplementsIdentifiers.formSave)
            }
        }
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog(String(localized: "Abandonner les modifications ?", bundle: .module), isPresented: $confirmsDiscard,
                            titleVisibility: .visible) {
            Button(String(localized: "Abandonner", bundle: .module), role: .destructive) { dismiss() }
            Button(String(localized: "Continuer à modifier", bundle: .module), role: .cancel) {}
        }
        .supplementArchiveConfirmation($archiving) { supplement in
            Task { await model.archive(supplement) }
        }
    }

    // MARK: Sections

    private var suggestions: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SupplementCatalog.suggestions) { suggestion in
                        Button(suggestion.name) { draft.apply(suggestion) }
                            .buttonStyle(PillButtonStyle(prominent: draft.suggestionID == suggestion.id))
                            .accessibilityAddTraits(draft.suggestionID == suggestion.id ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(String(localized: "Suggestions", bundle: .module))
        } footer: {
            Text(String(localized: "Une suggestion remplit tout sauf la dose : c'est la tienne.", bundle: .module))
        }
        .listRowBackground(Color.clear)
    }

    private var identity: some View {
        Section {
            TextField(String(localized: "Nom", bundle: .module), text: $draft.name)
                .frame(minHeight: 44)
                .accessibilityIdentifier(SupplementsIdentifiers.formName)
            Picker(String(localized: "Forme", bundle: .module), selection: $draft.form) {
                ForEach(SupplementForm.allCases, id: \.self) { Text(SupplementLabels.form($0)).tag($0) }
            }
            .frame(minHeight: 44)
            doseRow
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// « Dose par prise », le champ et l'unité : trois éléments liés. Le titre est lu par le champ, l'unité est la valeur du sélecteur.
    private var doseRow: some View {
        let title = String(localized: "Dose par prise", bundle: .module)
        // Le titre est lu par VoiceOver ; l'invite visible reste courte, pour ne pas être coupée dans la rangée.
        let field = TextField(title, value: $draft.dose, format: .number.locale(Locale(identifier: "fr_FR")),
                              prompt: Text(String(localized: "Dose", bundle: .module)))
            .pulseNumericKeyboard()
            .accessibilityIdentifier(SupplementsIdentifiers.formDose)
        let unit = Picker(String(localized: "Unité", bundle: .module), selection: $draft.unit) {
            ForEach(DoseUnit.allCases, id: \.self) { Text(SupplementLabels.unit($0)).tag($0) }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .accessibilityLabel(String(localized: "Unité", bundle: .module))
        .accessibilityValue(SupplementLabels.unitSpoken(draft.unit))
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).accessibilityHidden(true)
                    HStack {
                        field.frame(maxWidth: .infinity, alignment: .leading)
                        unit
                    }
                }
            } else {
                HStack {
                    Text(title).accessibilityHidden(true)
                    Spacer()
                    field.multilineTextAlignment(.trailing).frame(maxWidth: 100)
                    unit
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var moment: some View {
        Section(String(localized: "Moment", bundle: .module)) {
            ForEach(SupplementTiming.allCases, id: \.self) { timing in
                Button { draft.setTiming(timing) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: SupplementLabels.timingIcon(timing))
                            .frame(width: 24)
                            .foregroundStyle(PulsePalette.text2)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SupplementText.timing(timing)).foregroundStyle(PulsePalette.text)
                            Text(SupplementLabels.timingDetail(timing)).font(.footnote).foregroundStyle(PulsePalette.text2)
                        }
                        Spacer()
                        if draft.timing == timing {
                            Image(systemName: "checkmark").foregroundStyle(PulsePalette.text)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(draft.timing == timing ? .isSelected : [])
            }
            if draft.usesTime {
                DatePicker(String(localized: "Heure", bundle: .module), selection: timeBinding, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
            }
            Picker(String(localized: "Jours", bundle: .module), selection: $draft.days) {
                ForEach(SupplementDays.allCases, id: \.self) { Text(SupplementLabels.days($0)).tag($0) }
            }
            .frame(minHeight: 44)
            if draft.days == .custom {
                WeekdayToggleRow(selection: $draft.weekdays)
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var health: some View {
        Section {
            Picker(String(localized: "Écrire dans Apple Santé", bundle: .module), selection: $draft.healthType) {
                Text(SupplementLabels.healthType(nil)).tag(SupplementHealthType?.none)
                ForEach(SupplementHealthType.allCases, id: \.self) { type in
                    Text(SupplementLabels.healthType(type)).tag(SupplementHealthType?.some(type))
                }
            }
            .frame(minHeight: 44)
        } footer: {
            Text(draft.healthNote ?? String(localized: """
                Apple Santé a un type pour la vitamine D, le magnésium, la caféine et les protéines. Les autres restent dans Pulse.
                """, bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private var stock: some View {
        Section {
            numberRow(String(localized: "Doses restantes", bundle: .module), value: $draft.stock)
            if draft.stock != nil {
                numberRow(String(localized: "Prévenir sous", bundle: .module), value: $draft.threshold)
            }
        } header: {
            Text(String(localized: "Stock", bundle: .module))
        } footer: {
            Text(String(localized: "En prises : chaque prise retire 1. Laisse vide pour ne pas suivre le stock.", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }
}

// Les lignes et liaisons communes du formulaire, hors du corps du type pour qu'il reste court.
extension SupplementFormView {
    /// Le titre est le nom du champ pour VoiceOver ; « — » n'est que l'indice visuel d'un champ vide.
    private func numberRow(_ title: String, value: Binding<Double?>) -> some View {
        let field = TextField(title, value: value, format: .number.locale(Locale(identifier: "fr_FR")),
                              prompt: Text(String(localized: "—", bundle: .module)))
            .pulseNumericKeyboard()
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).accessibilityHidden(true)
                    field
                }
            } else {
                HStack {
                    Text(title).accessibilityHidden(true)
                    Spacer()
                    field.multilineTextAlignment(.trailing).frame(maxWidth: 100)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private func archiveSection(_ supplement: Supplement) -> some View {
        Section {
            Button(String(localized: "Archiver", bundle: .module), role: .destructive) { archiving = supplement }
                .frame(minHeight: 44)
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// L'heure du formulaire en `Date` pour le sélecteur, le jour n'a pas d'importance.
    private var timeBinding: Binding<Date> {
        let calendar = model.environment.calendar
        let day = calendar.startOfDay(for: model.environment.now())
        return Binding(
            get: { calendar.date(byAdding: .minute, value: draft.minutes, to: day) ?? day },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                draft.minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            })
    }
}
