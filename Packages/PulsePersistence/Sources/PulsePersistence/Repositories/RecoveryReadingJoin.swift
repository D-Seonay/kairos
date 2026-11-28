import Foundation
import PulseDomain

/// Recolle les valeurs brutes du magasin local sur les scores du magasin synchronisé, par jour civil.
enum RecoveryReadingJoin {
    /// Un jour sans lecture garde les valeurs brutes que sa ligne synchronisée porte encore (anciennes lignes). Deux lectures
    /// pour un même jour : la plus récente.
    static func fill(_ recoveries: [(key: String, recovery: DailyRecovery)], with readings: [StoredRecoveryReading],
                     calendar: Calendar) -> [DailyRecovery] {
        let byDay = DayRows.byDay(readings, calendar: calendar)
        return recoveries.map { key, recovery in
            guard let reading = byDay[key]?.first else { return recovery }
            var filled = recovery
            reading.fill(&filled)
            return filled
        }
    }
}
