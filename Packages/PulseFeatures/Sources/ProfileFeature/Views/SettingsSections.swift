import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

// MARK: - Mon profil

/// Prénom, date de naissance, sexe et taille. Le prénom et la taille s'écrivent à la validation ou quand le champ perd le focus.
struct ProfileSettingsSection: View {
    let model: SettingsModel
    let profile: UserProfile

    var body: some View {
        Section {
            SettingsTextField(title: String(localized: "Prénom", bundle: .module),
                              prompt: String(localized: "Facultatif", bundle: .module), stored: profile.firstName ?? "",
                              isNumeric: false) { [model] text in
                await model.update { $0.firstName = text }
                return model.profile?.firstName ?? ""
            }
            birthDate
            Picker(selection: sex) {
                ForEach(Sex.allCases, id: \.self) { Text(ProfileText.sex($0)).tag($0) }
            } label: {
                Text(String(localized: "Sexe", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .pickerStyle(.menu)
            .tint(PulsePalette.text2)
            .frame(minHeight: 44)
            SettingsTextField(title: String(localized: "Taille", bundle: .module),
                              prompt: String(localized: "Facultatif", bundle: .module), stored: Self.height(profile.heightCm),
                              unit: String(localized: "cm", bundle: .module), isNumeric: true) { [model] text in
                await model.commitHeight(text)
                return Self.height(model.profile?.heightCm)
            }
        } header: {
            Text(String(localized: "Mon profil", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Sans date, un bouton la propose (30 ans avant aujourd'hui, comme l'onboarding) ; jamais après aujourd'hui.
    @ViewBuilder
    private var birthDate: some View {
        let calendar = model.environment.calendar
        let today = model.environment.now()
        if let birthDate = profile.birthDate {
            DatePicker(selection: Binding(get: { birthDate }, set: { date in
                Task { await model.update { $0.birthDate = date } }
            }), in: ...today, displayedComponents: .date) {
                birthDateLabel
            }
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .frame(minHeight: 44)
        } else {
            Button {
                let suggested = calendar.date(byAdding: .year, value: -30, to: calendar.startOfDay(for: today)) ?? today
                Task { await model.update { $0.birthDate = suggested } }
            } label: {
                HStack {
                    birthDateLabel
                    Spacer(minLength: 8)
                    Text(String(localized: "Renseigner", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var birthDateLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Date de naissance", bundle: .module))
                .foregroundStyle(PulsePalette.text)
            Text(String(localized: "sert à la FC max des courses", bundle: .module))
                .font(.caption)
                .foregroundStyle(PulsePalette.text2)
        }
    }

    private var sex: Binding<Sex> {
        Binding(get: { profile.sex }, set: { value in Task { await model.update { $0.sex = value } } })
    }

    /// « 178 », « 178,5 » ; vide sans taille.
    static func height(_ centimeters: Double?) -> String {
        centimeters.map { PulseFormat.decimal($0, maxFractionDigits: 1) } ?? ""
    }
}

/// Un champ de texte qui n'écrit qu'à la validation ou quand il perd le focus, jamais à chaque frappe. `onCommit` écrit le texte
/// et rend la valeur stockée ensuite : le champ la reprend, même quand le texte a été refusé.
struct SettingsTextField: View {
    let title: String
    let prompt: String
    let stored: String
    var unit: String?
    let isNumeric: Bool
    let onCommit: (String) async -> String
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(PulsePalette.text)
            Spacer(minLength: 8)
            field
                .multilineTextAlignment(.trailing)
                .foregroundStyle(PulsePalette.text)
                .focused($isFocused)
                .onSubmit { isFocused = false }
            if let unit {
                Text(unit)
                    .foregroundStyle(PulsePalette.text2)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: stored, initial: true) { _, value in
            if !isFocused { text = value }
        }
    }

    @ViewBuilder
    private var field: some View {
        let label = TextField(title, text: $text, prompt: Text(prompt))
        if isNumeric {
            label
                .pulseNumericKeyboard()
                .toolbar {
                    #if os(iOS)
                    // Le clavier décimal n'a pas de touche Retour.
                    ToolbarItemGroup(placement: .keyboard) {
                        if isFocused {
                            Spacer()
                            Button(String(localized: "OK", bundle: .module)) { isFocused = false }
                        }
                    }
                    #endif
                }
        } else {
            label
                .pulseGivenNameField()
                .submitLabel(.done)
        }
    }

    private func commit() {
        guard text != stored else { return }
        let submitted = text
        Task {
            let value = await onCommit(submitted)
            if !isFocused { text = value }
        }
    }
}

// MARK: - Apple Santé

/// Une ligne par type lu, la dernière lecture, « Relire maintenant » et le diagnostic. HealthKit ne dit pas si la lecture est
/// refusée : l'écran donne la dernière donnée lue, jamais une autorisation (spec M7 §14).
struct HealthSettingsSection: View {
    /// L'ordre de la spec : le sommeil et la variabilité d'abord, le corps à la fin.
    static let order: [HealthSampleKind] = [.sleep, .sdnn, .restingHeartRate, .run, .ride, .bodyMass, .bodyFat]

    let model: SettingsModel
    let screens: ProfileAppScreens

    var body: some View {
        Section {
            if let health = model.health {
                ForEach(Self.order, id: \.self) { kind in
                    row(kind, latest: health.kinds.first { $0.kind == kind }?.latest)
                }
                Text(lastRead(health.lastRead))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .frame(minHeight: 32)
            } else {
                Text(String(localized: "Pulse n'a pas pu lire l'état d'Apple Santé.", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
            Button {
                Task { await model.refreshHealth() }
            } label: {
                HStack {
                    Text(String(localized: "Relire maintenant", bundle: .module))
                        .foregroundStyle(PulsePalette.text)
                    Spacer(minLength: 8)
                    if model.isRefreshingHealth { ProgressView() }
                }
            }
            .disabled(model.isRefreshingHealth)
            .frame(minHeight: 44)
            NavigationLink {
                screens.healthDiagnostics()
            } label: {
                Text(String(localized: "Diagnostic", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "Apple Santé", bundle: .module))
        } footer: {
            Text(String(
                localized: "Apple Santé ne dit pas à Pulse si l'accès est refusé. Pour le vérifier : Santé → Partage → Apps → Pulse.",
                bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private func row(_ kind: HealthSampleKind, latest: Date?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(ProfileText.healthKind(kind))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
            Spacer(minLength: 8)
            Text(latestText(latest))
                .font(.footnote)
                .foregroundStyle(latest == nil ? PulsePalette.muted : PulsePalette.text2)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    private func latestText(_ latest: Date?) -> String {
        guard let latest else { return String(localized: "Aucune donnée lue", bundle: .module) }
        let day = ProfileText.shortDate(latest, calendar: model.environment.calendar, today: model.environment.now())
        return String(localized: "dernière donnée le \(day)", bundle: .module)
    }

    private func lastRead(_ date: Date?) -> String {
        guard let date else { return String(localized: "Dernière lecture : jamais", bundle: .module) }
        return String(localized: "Dernière lecture : \(ProfileText.dateTime(date, calendar: model.environment.calendar))",
                      bundle: .module)
    }
}
