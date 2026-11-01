import PulseDomain

/// Ce que l'écran du jour affiche : la veille avant 4 h, un score, ou le check-in à faire.
public enum TodayScore: Sendable, Equatable {
    /// Avant 4 h, le jour n'a pas commencé : on garde le score de la veille, s'il existe.
    case beforeDayStart(yesterday: DailyRecovery?)
    case scored(DailyRecovery)
    /// Les données ne suffisent pas ; `missing` liste les facteurs absents.
    case needsCheckIn(missing: [Factor])
}

public enum DailyScoreError: Error, Equatable {
    /// Le score du jour est figé : il n'accepte plus de check-in.
    case frozen
}
