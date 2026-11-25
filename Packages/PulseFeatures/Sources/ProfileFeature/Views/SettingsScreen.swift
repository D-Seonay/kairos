import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
import TrainFeature

/// L'écran Paramètres (spec M7 §15), poussé depuis la page Profil : une liste stylée comme l'écran Poids et l'éditeur de
/// programme. Chaque réglage s'écrit dès qu'il change (les champs de texte à la validation ou quand ils perdent le focus) ; un
/// réglage refusé affiche son message en tête, la liste y remonte pour qu'il se voie, et l'écran revient à la valeur stockée.
struct SettingsScreen: View {
    @State private var model: SettingsModel
    let screens: ProfileAppScreens
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let errorID = "settings.error"

    /// `onProfileSaved` part après chaque écriture : l'app reprend le thème et le prénom, la page Profil se recharge.
    init(environment: ProfileEnvironment, screens: ProfileAppScreens, onProfileSaved: @escaping @MainActor (UserProfile) -> Void) {
        _model = State(initialValue: SettingsModel(environment: environment, onProfileSaved: onProfileSaved))
        self.screens = screens
    }

    var body: some View {
        ScrollViewReader { proxy in
            list
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // Un réglage refusé se règle souvent loin en bas : la liste remonte jusqu'à son message.
                // Le message vient d'être inséré : on attend le tour suivant, que sa ligne existe, avant d'y remonter.
                .onChange(of: model.failureCount) {
                    Task { @MainActor in
                        PulseMotion.perform(.default, reduceMotion: reduceMotion) { proxy.scrollTo(Self.errorID, anchor: .top) }
                    }
                }
        }
        .pulseAnnounceOnce(model.errorMessage, id: model.failureCount, isError: true)
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Paramètres", bundle: .module))
        .pulseInlineTitle()
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            // Au retour des réglages d'iOS, le message sur les notifications suit.
            if phase == .active { Task { await model.refreshNotificationStatus() } }
        }
    }

    private var list: some View {
        List {
            if let message = model.errorMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(Self.errorID)
                }
                .listRowBackground(PulsePalette.surface)
            }
            if let profile = model.profile {
                ProfileSettingsSection(model: model, profile: profile)
                HealthSettingsSection(model: model)
                AdaptationSettingsSection(model: model, profile: profile)
                AntiInterferenceSection(disabled: profile.antiInterferenceRulesDisabled) { rule, enabled in
                    Task { await model.update { $0.setRule(rule, enabled: enabled) } }
                }
                SessionSettingsSection(model: model, profile: profile)
                RunSettingsSection(model: model)
                DisplaySettingsSection(model: model, profile: profile)
                NotificationSettingsSection(model: model, profile: profile)
            } else if !model.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .accessibilityLabel(String(localized: "Chargement des réglages", bundle: .module))
                    .listRowBackground(Color.clear)
            }
            AboutSettingsSection(appVersion: model.environment.appVersion, screens: screens)
        }
    }
}

// MARK: - Affichage

/// L'ambiance Ivoire ou Acier. Le thème clair reste forcé : pas de choix Sombre / Clair / Auto (spec M7 §15).
struct DisplaySettingsSection: View {
    let model: SettingsModel
    let profile: UserProfile

    var body: some View {
        Section {
            ChoicePills(options: Theme.allCases.map { ($0, $0.title) },
                        selection: model.selection(profile.theme) { $0.theme = $1 },
                        groupLabel: String(localized: "Ambiance", bundle: .module))
                .padding(.vertical, 6)
        } header: {
            Text(String(localized: "Affichage", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }
}

// MARK: - À propos

/// La version et le build, les licences, et l'écran Diagnostic (Apple Santé, rapports de plantage et de lenteur), où l'on
/// vient le chercher pour l'assistance.
struct AboutSettingsSection: View {
    let appVersion: String
    let screens: ProfileAppScreens

    var body: some View {
        Section {
            LabeledContent(String(localized: "Version", bundle: .module), value: appVersion)
                .foregroundStyle(PulsePalette.text)
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            NavigationLink {
                LicensesView()
            } label: {
                Text(String(localized: "Licences", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
            NavigationLink {
                screens.healthDiagnostics()
            } label: {
                Text(String(localized: "Diagnostic", bundle: .module))
                    .foregroundStyle(PulsePalette.text)
            }
            .frame(minHeight: 44)
            Text(String(localized: """
                Pulse n'est pas un dispositif médical. \
                Le score et les ajustements sont des repères d'entraînement, pas un avis médical.
                """, bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
        } header: {
            Text(String(localized: "À propos", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }
}

#if DEBUG
/// Prépare l'environnement de l'aperçu puis pousse l'écran ; `notificationsDenied` montre le lien vers les réglages d'iOS.
private struct SettingsPreviewHost: View {
    var notificationsDenied = false
    @State private var environment: ProfileEnvironment?

    var body: some View {
        NavigationStack {
            if let environment {
                SettingsScreen(environment: environment, screens: ProfilePreviewSupport.screens) { _ in }
            } else {
                ProgressView()
            }
        }
        .task {
            var environment = await ProfilePreviewSupport.environment()
            let status: NotificationAuthorizationStatus = notificationsDenied ? .denied : .authorized
            environment.notificationStatus = { status }
            // Une nuit, une VFC, une FC au repos et une pesée lues ce matin ; ni course, ni vélo, ni masse grasse.
            let night = ProfilePreviewSupport.day(-1, hour: 23)
            let morning = ProfilePreviewSupport.day(0, hour: 7)
            try? await environment.healthCache.insert([
                CachedHealthSample(kind: .sleep, start: night, end: morning, sleepStage: .core, fetchedAt: morning),
                CachedHealthSample(kind: .sdnn, start: morning, end: morning, value: 52, fetchedAt: morning),
                CachedHealthSample(kind: .restingHeartRate, start: morning, end: morning, value: 54, fetchedAt: morning),
                CachedHealthSample(kind: .bodyMass, start: ProfilePreviewSupport.day(-2, hour: 7),
                                   end: ProfilePreviewSupport.day(-2, hour: 7), value: 78.2, fetchedAt: morning)
            ])
            self.environment = environment
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Paramètres") {
    SettingsPreviewHost()
}

#Preview("Paramètres, très grand texte") {
    SettingsPreviewHost()
        .dynamicTypeSize(.accessibility3)
}

#Preview("Paramètres, notifications coupées") {
    SettingsPreviewHost(notificationsDenied: true)
}
#endif
