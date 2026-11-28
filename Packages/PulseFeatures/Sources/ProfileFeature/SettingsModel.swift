import Foundation
import Observation
import PulseDomain
import PulseServices

/// L'état de l'écran Paramètres (spec M7 §15) : le profil, l'état de la lecture Apple Santé et des notifications. Chaque réglage
/// s'écrit par `update`, donc par `SettingsService` ; après une écriture, `onProfileSaved` prévient l'app (thème, prénom) et la
/// page Profil.
@MainActor
@Observable
public final class SettingsModel {
    public private(set) var profile: UserProfile?
    public private(set) var health: HealthReadStatus?
    public private(set) var notificationsDenied = false
    public private(set) var errorMessage: String?
    /// Un échec de plus : la même erreur revue est annoncée à nouveau.
    public private(set) var failureCount = 0
    public private(set) var isRefreshingHealth = false
    /// Faux tant que l'accès à Apple Santé n'a jamais été demandé sur cet appareil (étape passée à l'onboarding) : la section
    /// offre « Connecter Apple Santé ». HealthKit ne dit pas si la lecture est accordée : ce n'est pas un état « connecté ».
    public private(set) var healthAccessRequested = true
    /// Vrai pendant la demande d'accès : le bouton reste inactif.
    public private(set) var isConnectingHealth = false
    public private(set) var hasLoaded = false
    /// Les annonces vocales à chaque kilomètre de la course ; un réglage par appareil, hors du profil.
    public private(set) var announcesKilometres = true
    /// Le plan du sommeil (réveils habituels, coucher conseillé) : relu au chargement et après chaque réglage enregistré.
    public private(set) var sleepPlan: SleepPlan?
    /// Le rappel de check-in, réglé par appareil ; `nil` : l'app n'en offre pas.
    public internal(set) var checkInReminder: CheckInReminderSettings?

    @ObservationIgnored let environment: ProfileEnvironment
    @ObservationIgnored private let onProfileSaved: @MainActor (UserProfile) -> Void

    public init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void) {
        self.environment = environment
        self.onProfileSaved = onProfileSaved
    }

    /// Relit le profil, l'état d'Apple Santé et celui des notifications.
    public func load() async {
        announcesKilometres = environment.runPreferences.announcesKilometres
        checkInReminder = environment.checkInReminders?.settings
        do {
            profile = try await environment.settings.load()
            errorMessage = nil
        } catch {
            fail(error as? SettingsError == .noProfile
                ? Self.message(for: error)
                : String(localized: "Pulse n'a pas pu lire tes réglages.", bundle: .module))
        }
        sleepPlan = await environment.sleepPlan()
        await readHealth()
        healthAccessRequested = await environment.healthAccess?.wasRequested() ?? true
        await refreshNotificationStatus()
        hasLoaded = true
    }

    /// Écrit le réglage des annonces vocales de la course ; il vaut dès la prochaine course.
    public func setAnnouncesKilometres(_ on: Bool) {
        environment.runPreferences.setAnnouncesKilometres(on)
        announcesKilometres = on
    }

    /// Applique un réglage : l'écran le montre tout de suite, puis prend le profil enregistré. Une erreur affiche son message et
    /// relit le profil stocké : l'écran ne garde pas une valeur refusée. `onProfileSaved` ne part que si le profil a changé.
    public func update(_ change: @escaping @Sendable (inout UserProfile) -> Void) async {
        let before = profile
        if var shown = profile {
            change(&shown)
            profile = shown
        }
        do {
            let saved = try await environment.settings.update(change)
            let changed = saved != before
            profile = saved
            errorMessage = nil
            if changed { onProfileSaved(saved) }
            sleepPlan = await environment.sleepPlan()
        } catch {
            fail(Self.message(for: error))
            if let stored = try? await environment.settings.load() { profile = stored }
        }
    }

    /// La taille tapée, en centimètres : « 178 » ou « 178,5 » ; un champ vide efface la taille, un texte illisible est refusé
    /// comme une taille hors limites.
    public func commitHeight(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await update { $0.heightCm = nil }
            return
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }), let height = Double(normalized),
              height.isFinite else {
            fail(Self.message(for: SettingsError.invalidHeight))
            return
        }
        await update { $0.heightCm = height }
    }

    /// « Relire maintenant » : lance le passage du jour, puis relit l'état depuis le cache. Un appel pendant une relecture est ignoré.
    public func refreshHealth() async {
        guard !isRefreshingHealth else { return }
        isRefreshingHealth = true
        defer { isRefreshingHealth = false }
        await environment.refreshHealth()
        await readHealth()
    }

    /// « Connecter Apple Santé » : la demande d'accès de l'onboarding, puis le passage du jour comme au retour au premier plan,
    /// pour qu'un score mesuré arrive sans relancer l'app. Un appel pendant une demande est ignoré ; une demande qui échoue
    /// (Apple Santé indisponible) affiche son message et garde l'offre.
    public func connectHealth() async {
        guard let access = environment.healthAccess, !isConnectingHealth else { return }
        isConnectingHealth = true
        defer { isConnectingHealth = false }
        do {
            try await access.request()
        } catch {
            fail(String(localized: "Pulse n'a pas pu accéder à Apple Santé.", bundle: .module))
            return
        }
        healthAccessRequested = true
        errorMessage = nil
        await refreshHealth()
    }

    /// Relit l'autorisation des notifications : au retour des réglages d'iOS, le message suit. Pas encore demandée, elle n'affiche
    /// pas le lien : Pulse la demande quand une notification est allumée.
    public func refreshNotificationStatus() async {
        notificationsDenied = await environment.notificationStatus() == .denied
    }

    /// Un interrupteur de notification (score du matin, rappels de compléments, fin de repos). Allumé, il s'écrit puis demande
    /// l'autorisation à iOS si elle n'a pas encore été donnée ; refusée (maintenant ou avant), il se rééteint et le lien vers les
    /// réglages d'iOS s'affiche.
    public func setNotification(_ isOn: Bool, apply: @escaping @Sendable (inout UserProfile, Bool) -> Void) async {
        await update { apply(&$0, isOn) }
        guard isOn else { return }
        let granted = switch await environment.notificationStatus() {
        case .authorized: true
        case .denied: false
        case .notDetermined: await environment.requestNotificationAuthorization()
        }
        notificationsDenied = !granted
        if !granted { await update { apply(&$0, false) } }
    }

    private func fail(_ message: String) {
        errorMessage = message
        failureCount += 1
    }

    /// Une lecture du cache qui échoue garde l'état précédent.
    private func readHealth() async {
        if let status = try? await HealthReadStatus.read(cache: environment.healthCache) { health = status }
    }

    static func message(for error: any Error) -> String {
        switch error as? SettingsError {
        case .invalidHeight: String(localized: "Entre une taille entre 100 et 250 centimètres.", bundle: .module)
        case .invalidIncrement: String(localized: "L'incrément doit être positif.", bundle: .module)
        case .invalidRest: String(localized: "Choisis un repos de 60, 90, 120 ou 180 secondes.", bundle: .module)
        case .invalidDeadline: String(localized: "Choisis une heure entre 6 heures et 12 heures.", bundle: .module)
        case .invalidPlates: String(localized: "Garde au moins un disque et une barre de plus de 0 kilo.", bundle: .module)
        case .noProfile: String(localized: "Ton profil est introuvable.", bundle: .module)
        case .invalidSleepGoal, .invalidWakeTime, .invalidBedtimeLead, nil:
            String(localized: "Pulse n'a pas pu enregistrer ce réglage.", bundle: .module)
        }
    }
}

// MARK: - Sommeil

/// Ce que la section « Sommeil » affiche et écrit. Afficher n'écrit jamais rien : une valeur venue d'iCloud hors des choix est
/// montrée sur le choix le plus proche, ou comme « Selon mes nuits », et reste stockée telle quelle jusqu'au prochain geste.
extension SettingsModel {
    /// Les réveils de départ d'une « Heure choisie » : 07:00 en semaine, 09:00 le week-end, quel que soit le réveil habituel
    /// (une heure tirée d'Apple Santé n'est jamais écrite dans le profil).
    nonisolated static let defaultWeekdayWake = 7 * 60
    nonisolated static let defaultWeekendWake = 9 * 60

    /// L'objectif affiché : ramené dans les bornes (`SleepGoal.minutes(of:)`), puis sur le choix le plus proche.
    nonisolated static func shownSleepGoal(_ profile: UserProfile) -> Int {
        let goal = SleepGoal.minutes(of: profile)
        return SettingsService.sleepGoalChoices.min { abs($0 - goal) < abs($1 - goal) } ?? goal
    }

    /// L'avance affichée : celle du profil si elle est l'un des choix, sinon 30 minutes.
    nonisolated static func shownLead(_ profile: UserProfile) -> Int {
        profile.bedtimeReminderLeadMinutes.flatMap { SettingsService.bedtimeLeadChoices.contains($0) ? $0 : nil }
            ?? SleepPlan.defaultLeadMinutes
    }

    /// Le réveil choisi du groupe, s'il est dans les bornes ; sinon `nil`, affiché « Selon mes nuits » comme le fait `SleepPlan`.
    nonisolated static func chosenWake(_ profile: UserProfile, weekend: Bool) -> Int? {
        (weekend ? profile.weekendWakeMinutes : profile.weekdayWakeMinutes)
            .flatMap { SettingsService.wakeRange.contains($0) ? $0 : nil }
    }

    /// Un réveil prêt à écrire : arrondi à 5 minutes, ramené entre 04:00 et 12:00.
    nonisolated static func snappedWake(_ minutes: Int) -> Int {
        let step = SettingsService.wakeStepMinutes
        let rounded = Int((Double(minutes) / Double(step)).rounded()) * step
        return min(max(rounded, SettingsService.wakeRange.lowerBound), SettingsService.wakeRange.upperBound)
    }

    /// Le choix « Selon mes nuits » (`chosen` faux) écrit `nil`, jamais l'heure mesurée ; « Heure choisie » écrit le réveil de
    /// départ fixe (07:00 en semaine, 09:00 le week-end). Le choix déjà en place n'écrit rien.
    func chooseWake(_ chosen: Bool, weekend: Bool) async {
        guard let profile else { return }
        if chosen {
            guard Self.chosenWake(profile, weekend: weekend) == nil else { return }
            await setWake(weekend ? Self.defaultWeekendWake : Self.defaultWeekdayWake, weekend: weekend)
        } else {
            guard (weekend ? profile.weekendWakeMinutes : profile.weekdayWakeMinutes) != nil else { return }
            await update { $0.setWake(nil, weekend: weekend) }
        }
    }

    /// Écrit le réveil choisi, arrondi à 5 minutes.
    func setWake(_ minutes: Int, weekend: Bool) async {
        let wake = Self.snappedWake(minutes)
        await update { $0.setWake(wake, weekend: weekend) }
    }

    /// L'heure du `DatePicker` : le réveil, aujourd'hui, dans le calendrier de l'environnement.
    func wakeDate(_ minutes: Int) -> Date {
        let calendar = environment.calendar
        let today = calendar.startOfDay(for: environment.now())
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: today) ?? today
    }

    /// Les minutes après minuit d'une heure du `DatePicker`.
    func wakeMinutes(of date: Date) -> Int {
        let parts = environment.calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// De 04:00 à 12:00, aujourd'hui.
    var wakeDateRange: ClosedRange<Date> {
        wakeDate(SettingsService.wakeRange.lowerBound)...wakeDate(SettingsService.wakeRange.upperBound)
    }
}

extension UserProfile {
    /// Le réveil choisi en semaine ou le week-end ; `nil` : selon les nuits.
    mutating func setWake(_ minutes: Int?, weekend: Bool) {
        if weekend { weekendWakeMinutes = minutes } else { weekdayWakeMinutes = minutes }
    }
}
