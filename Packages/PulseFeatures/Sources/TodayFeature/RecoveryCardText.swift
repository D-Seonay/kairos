import Foundation
import PulseDesignSystem
import PulseDomain

/// Les textes parlés de la carte de récupération. Des fonctions pures.
enum RecoveryCardText {
    /// « Récupération 58 sur 100, fatigue modérée », suivi du marqueur parlé (« estimé », « en calibration, 9 nuits ») s'il y en a.
    static func gaugeLabel(recovery: DailyRecovery, marker: String?) -> String {
        let base = RecoveryGauge.accessibilityLabel(score: recovery.score, category: recovery.category)
        guard let marker, !marker.isEmpty else { return base }
        return String(localized: "\(base), \(marker)", bundle: .module)
    }
}
