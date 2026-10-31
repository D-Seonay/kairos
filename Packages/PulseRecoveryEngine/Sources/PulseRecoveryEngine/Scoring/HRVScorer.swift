/// Score VFC par paliers du z-score (cahier des charges §4.2).
public enum HRVScorer {
    public static func score(zScore z: Double) -> Double {
        if z >= 0.5 {
            return 100
        } else if z >= -0.5 {
            return 80 + (z + 0.5) * 20
        } else if z >= -1.5 {
            return 50 + (z + 1.5) * 30
        } else {
            return max(10, 50 + (z + 1.5) * 25)
        }
    }
}
