/// Score de fréquence cardiaque au repos par écart à la moyenne 7 jours (cahier des charges §4.3).
public enum RHRScorer {
    public static func score(todayBpm: Double, baselineMeanBpm: Double) -> Double {
        let delta = todayBpm - baselineMeanBpm
        if delta <= 0 {
            return 100
        } else if delta <= 7 {
            return 100 - delta * 8.5
        } else {
            return max(0, 40 - (delta - 7) * 10)
        }
    }
}
