import Foundation
import PulseDomain

public enum SettingsError: Error, Equatable {
    case noProfile
    case invalidHeight
    case invalidIncrement
    case invalidRest
    case invalidDeadline
    case invalidPlates
}

/// Le seul point d'écriture des réglages du profil (spec M7 §15) : normalise, valide, n'écrit que si le profil a changé, puis prévient
/// l'app pour qu'elle replanifie ce qui en dépend (notifications du matin, rappels de compléments, widgets).
public struct SettingsService: Sendable {
    public static let restChoices = [60, 90, 120, 180]
    public static let heightRange = 100.0...250.0
    /// Minutes après minuit : de 6 h à 12 h.
    public static let deadlineRange = 360...720

    private let profiles: any ProfileRepository
    private let now: @Sendable () -> Date
    private let onChange: @Sendable (UserProfile, UserProfile) async -> Void
    /// Les mises à jour rapides de l'écran Réglages ne s'entrelacent pas entre la lecture du profil et son écriture.
    private let queue = SerialTaskQueue()

    /// `onChange(ancien, nouveau)` part après chaque écriture réussie ; c'est là que l'app replanifie.
    public init(profiles: any ProfileRepository, now: @escaping @Sendable () -> Date,
                onChange: @escaping @Sendable (UserProfile, UserProfile) async -> Void) {
        self.profiles = profiles
        self.now = now
        self.onChange = onChange
    }

    public func load() async throws -> UserProfile {
        guard let profile = try await profiles.load() else { throw SettingsError.noProfile }
        return profile
    }

    /// Applique `change` à une copie du profil, normalise, valide, et n'enregistre (avec `updatedAt = now()`) que si quelque chose a
    /// changé. Une erreur de validation n'écrit rien et n'appelle rien ; un profil inchangé est rendu tel quel. Seuls les champs
    /// modifiés sont validés : une valeur déjà stockée hors limites (une taille lue dans Santé) ne bloque pas un autre réglage.
    /// Chaque appel s'exécute en entier (lecture, écriture, `onChange`) avant le suivant.
    @discardableResult
    public func update(_ change: @escaping @Sendable (inout UserProfile) -> Void) async throws -> UserProfile {
        try await queue.run {
            let old = try await load()
            var updated = old
            change(&updated)
            Self.normalize(&updated)
            try Self.validate(updated, against: old)
            guard updated != old else { return old }
            updated.updatedAt = now()
            try await profiles.save(updated)
            await onChange(old, updated)
            return updated
        }
    }

    /// Prénom rogné (vide : absent), disques positifs triés du plus lourd au plus léger, comme `ActiveSessionService.saveBarAndPlates`.
    private static func normalize(_ profile: inout UserProfile) {
        if let name = profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) {
            profile.firstName = name.isEmpty ? nil : name
        }
        profile.availablePlatesKg = profile.availablePlatesKg.filter { $0 > 0 }.sorted(by: >)
    }

    private static func validate(_ profile: UserProfile, against old: UserProfile) throws {
        if profile.heightCm != old.heightCm, let height = profile.heightCm, !heightRange.contains(height) {
            throw SettingsError.invalidHeight
        }
        if profile.upperIncrementKg != old.upperIncrementKg || profile.lowerIncrementKg != old.lowerIncrementKg {
            guard profile.upperIncrementKg > 0, profile.lowerIncrementKg > 0 else { throw SettingsError.invalidIncrement }
        }
        if profile.defaultRestSeconds != old.defaultRestSeconds, !restChoices.contains(profile.defaultRestSeconds) {
            throw SettingsError.invalidRest
        }
        if profile.morningScoreDeadlineMinutes != old.morningScoreDeadlineMinutes,
           let deadline = profile.morningScoreDeadlineMinutes, !deadlineRange.contains(deadline) {
            throw SettingsError.invalidDeadline
        }
        if profile.barWeightKg != old.barWeightKg || profile.availablePlatesKg != old.availablePlatesKg {
            guard profile.barWeightKg > 0, !profile.availablePlatesKg.isEmpty else { throw SettingsError.invalidPlates }
        }
    }
}
