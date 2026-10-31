/// Score de sommeil : durée (70) et part de sommeil profond (30) ; durée seule (100) sans phases (cahier des charges §4.4, spec §6.1).
public enum SleepScorer {
    static let targetMinutes = 480.0
    static let targetDeepRatio = 0.20

    public static func score(asleepMinutes: Int, deepMinutes: Int?) -> Double {
        guard asleepMinutes > 0 else { return 0 }
        let duration = min(1, Double(asleepMinutes) / targetMinutes)
        guard let deepMinutes else { return duration * 100 }
        let deepRatio = Double(deepMinutes) / Double(asleepMinutes)
        return duration * 70 + min(1, deepRatio / targetDeepRatio) * 30
    }
}
