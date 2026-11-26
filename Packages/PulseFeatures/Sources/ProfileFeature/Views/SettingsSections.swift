import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

// MARK: - Mon profil

/// Prénom, date de naissance, sexe et taille. Le prénom et la taille s'écrivent à la validation ou quand le champ perd le focus.
struct ProfileSettingsSection: View {
    let model: SettingsModel
    let profile: UserProfile
    /// « Renseigner » ouvre un sélecteur ; rien n'est écrit avant « Enregistrer ».
    @State private var isPickingBirthDate = false
    @State private var pendingBirthDate = Date()

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
            SettingsTextField(title: String(localized: "Taille", bundle: .module), spokenTitle: ProfileText.heightFieldLabel,
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

    /// Sans date, « Renseigner » ouvre un sélecteur réglé sur 30 ans avant aujourd'hui, comme l'onboarding, et n'écrit qu'à
    /// « Enregistrer » ; jamais après aujourd'hui.
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
            .accessibilityLabel(String(localized: "Date de naissance", bundle: .module))
            .accessibilityHint(ProfileText.birthDateHint)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.calendar, calendar)
            .environment(\.timeZone, calendar.timeZone)
            .frame(minHeight: 44)
        } else {
            Button {
                pendingBirthDate = calendar.date(byAdding: .year, value: -30, to: calendar.startOfDay(for: today)) ?? today
                isPickingBirthDate = true
            } label: {
                AdaptiveRow { isLarge in
                    birthDateLabel
                    if !isLarge { Spacer(minLength: 8) }
                    Text(String(localized: "Renseigner", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "Renseigner la date de naissance", bundle: .module))
            .accessibilityHint(ProfileText.birthDateHint)
            .sheet(isPresented: $isPickingBirthDate) { birthDateSheet(calendar: calendar, today: today) }
        }
    }

    /// Le sélecteur de « Renseigner » : la date proposée se règle, puis « Enregistrer » l'écrit ; « Annuler » n'écrit rien.
    private func birthDateSheet(calendar: Calendar, today: Date) -> some View {
        NavigationStack {
            Form {
                DatePicker(String(localized: "Date de naissance", bundle: .module), selection: $pendingBirthDate, in: ...today,
                           displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    .environment(\.calendar, calendar)
                    .environment(\.timeZone, calendar.timeZone)
                    .frame(minHeight: 44)
                    .listRowBackground(PulsePalette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(PulsePalette.background)
            .navigationTitle(String(localized: "Date de naissance", bundle: .module))
            .pulseInlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Annuler", bundle: .module)) { isPickingBirthDate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Enregistrer", bundle: .module)) {
                        let date = pendingBirthDate
                        isPickingBirthDate = false
                        Task { await model.update { $0.birthDate = date } }
                    }
                }
            }
        }
        .presentationDetents([.medium])
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
    /// Le nom lu par VoiceOver quand il dit plus que le titre (« Taille, en centimètres ») ; l'unité visible est tue.
    var spokenTitle: String?
    let prompt: String
    let stored: String
    var unit: String?
    let isNumeric: Bool
    let onCommit: (String) async -> String
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        AdaptiveRow { isLarge in
            Text(title)
                .foregroundStyle(PulsePalette.text)
                .accessibilityHidden(true)
            if !isLarge { Spacer(minLength: 8) }
            HStack(spacing: 8) {
                field
                    .multilineTextAlignment(isLarge ? .leading : .trailing)
                    .foregroundStyle(PulsePalette.text)
                    .focused($isFocused)
                    .onSubmit { isFocused = false }
                if let unit {
                    Text(unit)
                        .foregroundStyle(PulsePalette.text2)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(minHeight: 44)
        // Toute la ligne est tactile, pas seulement la hauteur du texte.
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: stored, initial: true) { _, value in
            if !isFocused { text = value }
        }
    }

    @ViewBuilder
    private var field: some View {
        let label = TextField(spokenTitle ?? title, text: $text, prompt: Text(prompt))
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

/// Une ligne par type lu, la dernière lecture et « Relire maintenant » ; le diagnostic est dans « À propos ». HealthKit ne dit
/// pas si la lecture est refusée : l'écran donne la dernière donnée lue, jamais une autorisation (spec M7 §14). Tant que Pulse
/// n'a jamais demandé l'accès (étape passée à l'onboarding), la section commence par « Connecter Apple Santé » : iOS ne liste
/// pas l'app dans Santé avant cette demande. Une fois faite, le pied de section renvoie à Santé → Partage.
struct HealthSettingsSection: View {
    /// L'ordre de la spec : le sommeil et la variabilité d'abord, le corps à la fin.
    static let order: [HealthSampleKind] = [.sleep, .sdnn, .restingHeartRate, .run, .ride, .bodyMass, .bodyFat]

    let model: SettingsModel

    var body: some View {
        Section {
            if !model.healthAccessRequested { connectButton }
            if let health = model.health {
                ForEach(Self.order, id: \.self) { kind in
                    row(kind, latest: health.kinds.first { $0.kind == kind }?.latest)
                }
                Text(lastRead(health.lastRead))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .frame(minHeight: 32)
                    .accessibilityLabel(ProfileText.lastReadSpoken(health.lastRead, calendar: model.environment.calendar,
                                                                   today: model.environment.now()))
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
                    if model.isRefreshingHealth {
                        ProgressView()
                            .accessibilityLabel(ProfileText.healthReadStarted)
                    }
                }
            }
            .disabled(model.isRefreshingHealth)
            .frame(minHeight: 44)
            // La relecture se lance d'une touche et finit sans que le focus bouge : début et fin sont annoncés. Posé sur ce seul
            // bouton, pas sur la section (un modificateur de section se répète par rangée).
            .onChange(of: model.isRefreshingHealth) { _, isRefreshing in
                PulseAnnouncement.post(isRefreshing ? ProfileText.healthReadStarted : ProfileText.healthReadFinished)
            }
        } header: {
            Text(String(localized: "Apple Santé", bundle: .module))
        } footer: {
            Text(footer)
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Demande l'accès à Apple Santé (la feuille d'iOS), puis relit le jour : « Relire maintenant » montre la lecture en cours.
    private var connectButton: some View {
        Button {
            Task { await model.connectHealth() }
        } label: {
            HStack {
                Text(String(localized: "Connecter Apple Santé", bundle: .module))
                    .fontWeight(.semibold)
                    .foregroundStyle(PulsePalette.text)
                Spacer(minLength: 8)
                if model.isConnectingHealth {
                    ProgressView()
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(model.isConnectingHealth)
        .frame(minHeight: 44)
        .accessibilityHint(String(localized: "Ouvre la demande d'accès d'Apple Santé", bundle: .module))
        .accessibilityIdentifier(ProfileIdentifiers.connectHealth)
    }

    /// Avant la demande : pourquoi connecter. Après : où vérifier l'accès, que HealthKit ne dit pas à Pulse.
    private var footer: String {
        guard model.healthAccessRequested else {
            return String(
                localized: "Pulse n'a pas encore demandé l'accès à Apple Santé. Connecte-le pour mesurer ta récupération chaque matin.",
                bundle: .module)
        }
        return String(
            localized: "Apple Santé ne dit pas à Pulse si l'accès est refusé. Pour le vérifier : Santé → Partage → Apps → Pulse.",
            bundle: .module)
    }

    private func row(_ kind: HealthSampleKind, latest: Date?) -> some View {
        AdaptiveRow(spacing: 12) { isLarge in
            Text(ProfileText.healthKind(kind))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulsePalette.text)
            if !isLarge { Spacer(minLength: 8) }
            Text(latestText(latest))
                .font(.footnote)
                .foregroundStyle(latest == nil ? PulsePalette.muted : PulsePalette.text2)
                .multilineTextAlignment(isLarge ? .leading : .trailing)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProfileText.healthRowSpoken(kind, latest: latest, calendar: model.environment.calendar,
                                                        today: model.environment.now()))
    }

    private func latestText(_ latest: Date?) -> String {
        guard let latest else { return String(localized: "Aucune donnée lue", bundle: .module) }
        let day = ProfileText.shortDate(latest, calendar: model.environment.calendar, today: model.environment.now())
        return String(localized: "dernière donnée le \(day)", bundle: .module)
    }

    /// `HealthReadStatus.lastRead` date la dernière donnée arrivée dans le cache, pas la dernière lecture d'Apple Santé : une
    /// lecture qui ne rapporte rien ne la change pas.
    private func lastRead(_ date: Date?) -> String {
        guard let date else { return String(localized: "Dernière donnée reçue : jamais", bundle: .module) }
        return String(localized: "Dernière donnée reçue : \(ProfileText.dateTime(date, calendar: model.environment.calendar))",
                      bundle: .module)
    }
}
