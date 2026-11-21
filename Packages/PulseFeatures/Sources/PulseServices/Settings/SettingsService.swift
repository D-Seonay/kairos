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
    /// changé. Une erreur de validation n'écrit rien et n'appelle rien ; un profil inchangé est rendu tel quel.
    @discardableResult
    public func update(_ change: @Sendable (inout UserProfile) -> Void) async throws -> UserProfile {
        let old = try await load()
        var updated = old
        change(&updated)
        Self.normalize(&updated)
        try Self.validate(updated)
        guard updated != old else { return old }
        updated.updatedAt = now()
        try await profiles.save(updated)
        await onChange(old, updated)
        return updated
    }

    /// Prénom rogné (vide : absent), disques positifs triés du plus lourd au plus léger, comme `ActiveSessionService.saveBarAndPlates`.
    private static func normalize(_ profile: inout UserProfile) {
        if let name = profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) {
            profile.firstName = name.isEmpty ? nil : name
        }
        profile.availablePlatesKg = profile.availablePlatesKg.filter { $0 > 0 }.sorted(by: >)
    }

    private static func validate(_ profile: UserProfile) throws {
        if let height = profile.heightCm, !heightRange.contains(height) { throw SettingsError.invalidHeight }
        guard profile.upperIncrementKg > 0, profile.lowerIncrementKg > 0 else { throw SettingsError.invalidIncrement }
        guard restChoices.contains(profile.defaultRestSeconds) else { throw SettingsError.invalidRest }
        if let deadline = profile.morningScoreDeadlineMinutes, !deadlineRange.contains(deadline) { throw SettingsError.invalidDeadline }
        guard profile.barWeightKg > 0, !profile.availablePlatesKg.isEmpty else { throw SettingsError.invalidPlates }
    }
}
