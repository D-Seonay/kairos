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
    public private(set) var hasLoaded = false
    /// Les annonces vocales à chaque kilomètre de la course ; un réglage par appareil, hors du profil.
    public private(set) var announcesKilometres = true

    @ObservationIgnored let environment: ProfileEnvironment
    @ObservationIgnored private let onProfileSaved: @MainActor (UserProfile) -> Void

    public init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void) {
        self.environment = environment
        self.onProfileSaved = onProfileSaved
    }

    /// Relit le profil, l'état d'Apple Santé et celui des notifications.
    public func load() async {
        announcesKilometres = environment.runPreferences.announcesKilometres
        do {
            profile = try await environment.settings.load()
            errorMessage = nil
        } catch {
            fail(error as? SettingsError == .noProfile
                ? Self.message(for: error)
                : String(localized: "Pulse n'a pas pu lire tes réglages.", bundle: .module))
        }
        await readHealth()
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
        case nil: String(localized: "Pulse n'a pas pu enregistrer ce réglage.", bundle: .module)
        }
    }
}
