/// L'objectif de sommeil : la durée visée chaque nuit, 8 h par défaut, de 6 h à 10 h par pas de 15 min.
/// Une nuit est courte quand elle reste plus d'une heure sous l'objectif.
public enum SleepGoal {
    public static let defaultMinutes = 480
    public static let range = 360...600
    public static let stepMinutes = 15
    public static let shortNightMarginMinutes = 60

    /// L'objectif du profil ramené dans `range`, `defaultMinutes` sans profil ou sans valeur.
    public static func minutes(of profile: UserProfile?) -> Int {
        guard let minutes = profile?.sleepGoalMinutes else { return defaultMinutes }
        return min(max(minutes, range.lowerBound), range.upperBound)
    }

    /// Strictement plus d'une heure sous l'objectif : 7 h pile n'est pas une nuit courte à l'objectif par défaut.
    public static func isShortNight(asleepMinutes: Int, goalMinutes: Int) -> Bool {
        asleepMinutes < goalMinutes - shortNightMarginMinutes
    }
}
