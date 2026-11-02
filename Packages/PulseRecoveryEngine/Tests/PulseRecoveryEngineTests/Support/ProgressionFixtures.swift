import Foundation
import PulseDomain
@testable import PulseRecoveryEngine

extension ProgressionPolicy {
    /// Politique où la hausse est permise.
    static let open = ProgressionPolicy(allowsIncrease: true)
    /// Politique où la hausse est refusée (fatigue, score estimé…).
    static let closed = ProgressionPolicy(allowsIncrease: false)
}

extension DailyRecovery {
    /// Score mesuré, calibré (sauf si `calibrating` donne le nombre de nuits), avec ses facteurs manquants.
    static func measured(score: Double, missing: [Factor] = [], calibrating nights: Int? = nil) -> DailyRecovery {
        DailyRecovery(day: TestCalendar.day(2026, 11, 2), score: score, category: RecoveryCategory(score: score),
                      isEstimated: false, missingFactors: missing,
                      calibration: nights.map { .calibrating(nights: $0) } ?? .ready,
                      createdAt: TestCalendar.day(2026, 11, 2), updatedAt: TestCalendar.day(2026, 11, 2))
    }

    /// Score estimé à partir du check-in.
    static func estimated(score: Double) -> DailyRecovery {
        DailyRecovery(day: TestCalendar.day(2026, 11, 2), score: score, category: RecoveryCategory(score: score),
                      isEstimated: true, calibration: .ready,
                      createdAt: TestCalendar.day(2026, 11, 2), updatedAt: TestCalendar.day(2026, 11, 2))
    }
}
