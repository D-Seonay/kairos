import Foundation
import PulseDomain

/// Le pas de progression de la charge d'un exercice.
public enum IncrementResolver {
    /// Le réglage de l'exercice s'il existe ; sinon le plus petit de l'incrément par défaut de l'exercice et de celui du profil
    /// (bas du corps pour `.lower`, haut du corps sinon) ; sans profil, l'incrément par défaut.
    public static func increment(for info: ExerciseInfo, settings: ExerciseSettings?, profile: UserProfile?) -> Double {
        if let chosen = settings?.incrementKg { return chosen }
        guard let profile else { return info.defaultIncrementKg }
        let preferred = info.region == .lower ? profile.lowerIncrementKg : profile.upperIncrementKg
        return min(info.defaultIncrementKg, preferred)
    }
}
