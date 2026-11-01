/// Les jeux de données nommés de la fausse source Apple Santé, utilisés par les tests, les aperçus et le test d'interface.
public enum HealthScenario: String, CaseIterable, Sendable {
    /// Nuit du jour excellente, ligne de base complète : score optimal.
    case goodNight
    /// Nuit du jour courte et agitée : fatigue modérée.
    case badNight
    /// Comme `goodNight`, sans mesure de VFC.
    case missingHRV
    /// Seulement les trois dernières nuits : ligne de base impossible, check-in demandé.
    case threeNights
    /// Aucune donnée.
    case noData
}
