import Foundation
import PulseDesignSystem
import PulseDomain

/// Les textes parlés du check-in. Des fonctions pures.
public enum CheckInText {
    /// « Estimation : 58 sur 100, fatigue modérée » ; « Estimation : réponds aux trois questions » tant que le score manque.
    public static func estimation(score: Double?, category: RecoveryCategory?) -> String {
        let title = String(localized: "Estimation", bundle: .module)
        guard let score, score.isFinite, let category else {
            let ask = String(localized: "réponds aux trois questions", bundle: .module)
            return String(localized: "\(title) : \(ask)", bundle: .module)
        }
        let value = PulseSpoken.outOf(Int(min(max(score, 0), 100).rounded()), 100)
        let name = category.localizedName.lowercased()
        return String(localized: "\(title) : \(value), \(name)", bundle: .module)
    }

    /// Ce qu'on annonce quand l'estimation devient disponible ou change ; `nil` tant qu'il manque une réponse.
    public static func announcement(score: Double?, category: RecoveryCategory?) -> String? {
        guard let score, score.isFinite, category != nil else { return nil }
        return estimation(score: score, category: category)
    }
}
