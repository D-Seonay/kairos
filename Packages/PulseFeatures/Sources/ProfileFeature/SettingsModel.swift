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
    public private(set) var isRefreshingHealth = false
    public private(set) var hasLoaded = false

    @ObservationIgnored let environment: ProfileEnvironment
    @ObservationIgnored private let onProfileSaved: @MainActor (UserProfile) -> Void

    public init(environment: ProfileEnvironment, onProfileSaved: @escaping @MainActor (UserProfile) -> Void) {
        self.environment = environment
        self.onProfileSaved = onProfileSaved
    }

    /// Relit le profil, l'état d'Apple Santé et celui des notifications.
    public func load() async {
        do {
            profile = try await environment.settings.load()
            errorMessage = nil
        } catch {
            errorMessage = error as? SettingsError == .noProfile
                ? Self.message(for: error)
                : String(localized: "Pulse n'a pas pu lire tes réglages.", bundle: .module)
        }
        await readHealth()
        await refreshNotificationStatus()
        hasLoaded = true
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
            errorMessage = Self.message(for: error)
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
            errorMessage = Self.message(for: SettingsError.invalidHeight)
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

    /// Relit l'autorisation des notifications : au retour des réglages d'iOS, le message suit.
    public func refreshNotificationStatus() async {
        notificationsDenied = await environment.notificationsDenied()
    }

    /// Une lecture du cache qui échoue garde l'état précédent.
    private func readHealth() async {
        if let status = try? await HealthReadStatus.read(cache: environment.healthCache) { health = status }
    }

    static func message(for error: any Error) -> String {
        switch error as? SettingsError {
        case .invalidHeight: String(localized: "Entre une taille entre 100 et 250 cm.", bundle: .module)
        case .invalidIncrement: String(localized: "L'incrément doit être positif.", bundle: .module)
        case .invalidRest: String(localized: "Choisis un repos de 60, 90, 120 ou 180 s.", bundle: .module)
        case .invalidDeadline: String(localized: "Choisis une heure entre 6 h et 12 h.", bundle: .module)
        case .invalidPlates: String(localized: "Garde au moins un disque et une barre de plus de 0 kg.", bundle: .module)
        case .noProfile: String(localized: "Ton profil est introuvable.", bundle: .module)
        case nil: String(localized: "Pulse n'a pas pu enregistrer ce réglage.", bundle: .module)
        }
    }
}
