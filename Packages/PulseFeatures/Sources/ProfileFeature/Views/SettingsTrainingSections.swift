import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Moteur d'adaptation

/// L'ajustement automatique et les incréments de charge, par pas de 0,5 kg de 0,5 à 10 kg. Les règles anti-interférence suivent,
/// dans leur propre section.
struct AdaptationSettingsSection: View {
    static let incrementRange = 0.5...10.0
    static let incrementStep = 0.5

    let model: SettingsModel
    let profile: UserProfile

    var body: some View {
        Section {
            SettingsToggle(title: String(localized: "Ajuster mes séances automatiquement", bundle: .module),
                           isOn: model.binding(profile.adaptationEnabled) { $0.adaptationEnabled = $1 })
            increment(String(localized: "Incrément haut du corps", bundle: .module),
                      value: model.binding(profile.upperIncrementKg) { $0.upperIncrementKg = $1 })
            increment(String(localized: "Incrément bas du corps", bundle: .module),
                      value: model.binding(profile.lowerIncrementKg) { $0.lowerIncrementKg = $1 })
        } header: {
            Text(String(localized: "Moteur d'adaptation", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    private func increment(_ title: String, value: Binding<Double>) -> some View {
        Stepper(value: value, in: Self.incrementRange, step: Self.incrementStep) {
            AdaptiveRow { isLarge in
                Text(title)
                    .foregroundStyle(PulsePalette.text)
                if !isLarge { Spacer(minLength: 8) }
                Text(ProfileText.weight(value.wrappedValue))
                    .font(PulseFont.value(.body))
                    .foregroundStyle(PulsePalette.text)
            }
        }
        // Le titre est le nom, la valeur dite (« 2,5 kilos ») suit chaque ajustement.
        .accessibilityLabel(title)
        .accessibilityValue(ProfileText.weightSpoken(value.wrappedValue))
        .frame(minHeight: 44)
    }
}

// MARK: - Séance

/// L'échauffement automatique, le repos par défaut, la barre et les disques disponibles.
struct SessionSettingsSection: View {
    /// Les barres et les disques du calculateur de disques de la séance (`PlateCalculatorSheet`), du plus lourd au plus léger.
    static let barChoices: [Double] = [10, 15, 20]
    static let plateChoices: [Double] = [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5]

    let model: SettingsModel
    let profile: UserProfile

    var body: some View {
        Section {
            SettingsToggle(title: String(localized: "Échauffement automatique", bundle: .module),
                           isOn: model.binding(profile.autoWarmupEnabled) { $0.autoWarmupEnabled = $1 })
            let restTitle = String(localized: "Repos par défaut", bundle: .module)
            pills(restTitle, spoken: restTitle) { group in
                ChoicePills(options: SettingsService.restChoices.map { ($0, String(localized: "\($0) s", bundle: .module)) },
                            selection: model.selection(profile.defaultRestSeconds) { $0.defaultRestSeconds = $1 },
                            groupLabel: group, spokenLabel: { ProfileText.restSpoken($0) })
                // Le moteur ne prend ce repos que pour un exercice sans repos au catalogue ; les lignes de routine gardent le leur.
                Text(String(
                    localized: "S'applique aux exercices sans repos conseillé. Les exercices de ton programme gardent leur propre repos.",
                    bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            pills(String(localized: "Barre (kg)", bundle: .module), spoken: String(localized: "Barre", bundle: .module)) { group in
                ChoicePills(options: Self.barChoices.map { ($0, Self.kilos($0)) },
                            selection: model.selection(profile.barWeightKg) { $0.barWeightKg = $1 },
                            groupLabel: group, spokenLabel: { ProfileText.plateSpoken($0) })
            }
            pills(String(localized: "Disques disponibles (kg)", bundle: .module),
                  spoken: String(localized: "Disques disponibles", bundle: .module)) { group in
                MultiChoicePills(options: Self.plateChoices.map { ($0, Self.kilos($0)) }, selection: plates,
                                 groupLabel: group, spokenLabel: { ProfileText.plateSpoken($0) })
            }
        } header: {
            Text(String(localized: "Séance", bundle: .module))
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Le titre visible et les pastilles ; VoiceOver lit `spoken` une fois, comme nom du groupe, et chaque pastille avec son unité.
    private func pills(_ title: String, spoken: String, @ViewBuilder content: (String) -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundStyle(PulsePalette.text)
                .accessibilityHidden(true)
            content(spoken)
        }
        .padding(.vertical, 6)
    }

    /// Chaque toucher écrit un changement, pas l'ensemble affiché : le disque basculé est ajouté ou retiré des disques stockés,
    /// donc deux touchers rapprochés ne s'effacent pas. Un disque stocké absent des puces reste.
    private var plates: Binding<Set<Double>> {
        let shown = Set(profile.availablePlatesKg)
        return Binding(get: { shown }, set: { [model] newValue in
            for plate in newValue.subtracting(shown) {
                Task { await model.update { $0.setPlate(plate, available: true) } }
            }
            for plate in shown.subtracting(newValue) {
                Task { await model.update { $0.setPlate(plate, available: false) } }
            }
        })
    }

    /// « 2,5 », « 1,25 » : l'unité est dans le titre.
    private static func kilos(_ value: Double) -> String {
        PulseFormat.decimal(value, maxFractionDigits: 2)
    }
}

// MARK: - Notifications

/// Le score du matin et son heure plafond, les rappels de compléments, la fin de repos ; un lien vers les réglages d'iOS quand les
/// notifications de Pulse y sont coupées.
struct NotificationSettingsSection: View {
    /// De 6 h à 12 h, par demi-heure.
    static let deadlines = Array(stride(from: SettingsService.deadlineRange.lowerBound,
                                        through: SettingsService.deadlineRange.upperBound, by: 30))

    let model: SettingsModel
    let profile: UserProfile
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            if model.notificationsDenied { denied }
            SettingsToggle(title: String(localized: "Score du matin", bundle: .module),
                           isOn: model.notificationBinding(profile.morningScoreNotification) { $0.morningScoreNotification = $1 })
            if profile.morningScoreNotification {
                Picker(selection: deadline) {
                    ForEach(Self.deadlines, id: \.self) { Text(PulseFormat.duration(minutes: $0)).tag($0) }
                } label: {
                    Text(String(localized: "Heure plafond", bundle: .module))
                        .foregroundStyle(PulsePalette.text)
                }
                .pickerStyle(.menu)
                .tint(PulsePalette.text2)
                .accessibilityValue(ProfileText.clockSpoken(
                    minutes: profile.morningScoreDeadlineMinutes ?? MorningNotificationRule.defaultDeadlineMinutes))
                .frame(minHeight: 44)
            }
            SettingsToggle(title: String(localized: "Rappels de compléments", bundle: .module),
                           isOn: model.notificationBinding(profile.supplementRemindersEnabled) {
                               $0.supplementRemindersEnabled = $1
                           })
            SettingsToggle(title: String(localized: "Fin de repos", bundle: .module),
                           isOn: model.notificationBinding(profile.restTimerNotificationEnabled) {
                               $0.restTimerNotificationEnabled = $1
                           })
        } header: {
            Text(String(localized: "Notifications", bundle: .module))
        } footer: {
            if profile.morningScoreNotification {
                Text(String(localized: "Après l'heure plafond, Pulse n'annonce plus le score du matin.", bundle: .module))
            }
        }
        .listRowBackground(PulsePalette.surface)
    }

    /// Sans heure choisie, 10 h (`MorningNotificationRule.defaultDeadlineMinutes`).
    private var deadline: Binding<Int> {
        model.binding(profile.morningScoreDeadlineMinutes ?? MorningNotificationRule.defaultDeadlineMinutes) {
            $0.morningScoreDeadlineMinutes = $1
        }
    }

    private var denied: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Les notifications de Pulse sont coupées dans les réglages d'iOS.", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.signal)
                .fixedSize(horizontal: false, vertical: true)
            #if canImport(UIKit)
            Button(String(localized: "Ouvrir les réglages d'iOS", bundle: .module)) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PillButtonStyle())
            #endif
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Éléments communs

/// Un interrupteur de réglage, encre sur papier.
struct SettingsToggle: View {
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(isOn: isOn) {
            Text(title)
                .foregroundStyle(PulsePalette.text)
        }
        .tint(PulsePalette.ink)
        .frame(minHeight: 44)
    }
}

extension SettingsModel {
    /// Le lien d'un réglage qui s'écrit dès qu'il change : `value` est la valeur affichée, `apply` l'écrit dans le profil.
    func binding<Value: Sendable>(_ value: Value,
                                  apply: @escaping @Sendable (inout UserProfile, Value) -> Void) -> Binding<Value> {
        Binding(get: { value }, set: { newValue in
            Task { await self.update { apply(&$0, newValue) } }
        })
    }

    /// Le lien d'un interrupteur de notification : allumé, il demande l'autorisation d'iOS si besoin (`setNotification`).
    func notificationBinding(_ value: Bool, apply: @escaping @Sendable (inout UserProfile, Bool) -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: { newValue in
            Task { await self.setNotification(newValue, apply: apply) }
        })
    }

    /// Le même lien pour les puces à choix unique, qui lisent une valeur facultative : un `nil` est ignoré.
    func selection<Value: Sendable>(_ value: Value,
                                    apply: @escaping @Sendable (inout UserProfile, Value) -> Void) -> Binding<Value?> {
        Binding(get: { value }, set: { newValue in
            guard let newValue else { return }
            Task { await self.update { apply(&$0, newValue) } }
        })
    }
}

extension UserProfile {
    /// Ajoute ou retire un disque des disques disponibles ; `SettingsService` trie et filtre ensuite.
    mutating func setPlate(_ plate: Double, available: Bool) {
        availablePlatesKg.removeAll { $0 == plate }
        if available { availablePlatesKg.append(plate) }
    }
}
