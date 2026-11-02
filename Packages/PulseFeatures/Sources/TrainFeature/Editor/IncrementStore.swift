import Foundation
import PulseDomain

/// L'incrément de charge d'un exercice, écrit dans `ExerciseSettings` : la fiche exercice et l'éditeur de routine s'en servent.
struct IncrementStore {
    static let range = 0.25...20.0
    static let step = 0.25

    let settings: any ExerciseSettingsRepository

    /// `kg` arrondi au quart de kilo, entre 0,25 et 20 kg.
    static func clamped(_ kg: Double) -> Double {
        min(max((kg / step).rounded() * step, range.lowerBound), range.upperBound)
    }

    /// Enregistre l'incrément (déjà borné) en gardant les autres réglages de l'exercice ; rend le réglage enregistré.
    @discardableResult
    func save(_ kg: Double, for reference: ExerciseReference, now: Date) async throws -> ExerciseSettings {
        var current = try await settings.settings(for: reference)
            ?? ExerciseSettings(exercise: reference, createdAt: now, updatedAt: now)
        current.incrementKg = Self.clamped(kg)
        current.updatedAt = now
        try await settings.save(current)
        return current
    }
}
