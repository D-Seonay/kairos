import PulseDomain

/// La semaine de décharge (spec M6 §10) : 40 % de séries en moins sur chaque séance de musculation, des charges 10 % plus
/// basses. Les exercices gardent leur ordre et leur identité ; les super sets perdent leurs séries ensemble.
public enum DeloadAdjuster {
    public static let volumeReduction = 0.4
    /// Le facteur appliqué aux charges proposées pendant la décharge.
    public static let loadFactor = 0.9

    /// L'ajustement nommé que porte une séance lancée pendant une décharge, appliquée ou refusée.
    public static var adjustment: SessionAdjustment {
        SessionAdjustment(kind: .deload, reason: String(localized: "Semaine de décharge : volume −40 %, charges −10 %", bundle: .module),
                          value: volumeReduction)
    }

    /// Retire 40 % des séries d'un jour de musculation ; un jour de course reste tel quel.
    public static func apply(_ day: RoutineDay) -> AdjustedSession {
        guard day.kind == .strength else { return AdjustedSession(day: day) }
        let reduced = VolumeReducer.reduce(day.exercises, by: volumeReduction)
        var adjusted = day
        adjusted.exercises = reduced.exercises
        return AdjustedSession(day: adjusted, adjustments: [adjustment], removedSets: reduced.removedSets)
    }
}
