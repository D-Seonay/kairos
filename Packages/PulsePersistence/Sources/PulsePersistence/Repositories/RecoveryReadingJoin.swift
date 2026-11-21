import Foundation
import PulseDomain

/// Recolle les valeurs brutes du magasin local sur les scores du magasin synchronisé, jour par jour.
enum RecoveryReadingJoin {
    /// Un jour sans lecture garde les valeurs brutes que sa ligne synchronisée porte encore (anciennes lignes).
    static func fill(_ recoveries: [DailyRecovery], with readings: [StoredRecoveryReading]) -> [DailyRecovery] {
        let byDay = Dictionary(readings.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        return recoveries.map { recovery in
            guard let reading = byDay[recovery.day] else { return recovery }
            var filled = recovery
            reading.fill(&filled)
            return filled
        }
    }
}
