import PulseDomain

/// Score de sommeil : durée (70) et part de sommeil profond (30) ; durée seule (100) sans phases (cahier des charges §4.4, spec §6.1).
/// La durée se mesure contre `targetMinutes`, l'objectif de sommeil du profil (8 h par défaut).
public enum SleepScorer {
    static let targetDeepRatio = 0.20

    public static func score(asleepMinutes: Int, deepMinutes: Int?, targetMinutes: Int = SleepGoal.defaultMinutes) -> Double {
        guard asleepMinutes > 0 else { return 0 }
        let duration = min(1, Double(asleepMinutes) / Double(targetMinutes))
        guard let deepMinutes else { return duration * 100 }
        let deepRatio = Double(deepMinutes) / Double(asleepMinutes)
        return duration * 70 + min(1, deepRatio / targetDeepRatio) * 30
    }
}
