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

    /// Le titre et la phrase de la bannière. Accès à Apple Santé déjà demandé : les données de nuit manquent, la montre est
    /// sans doute en cause. Jamais demandé (étape passée à l'onboarding) : la bannière dit qu'Apple Santé n'est pas connecté,
    /// sans parler d'une montre que la personne n'a peut-être pas.
    public static func banner(healthRequested: Bool) -> (title: String, message: String) {
        if healthRequested {
            return (String(localized: "Pas de données de nuit", bundle: .module),
                    String(localized: "Montre déchargée ou non portée ? Trois questions suffisent pour estimer ta récupération.",
                           bundle: .module))
        }
        return (String(localized: "Apple Santé n'est pas connecté", bundle: .module),
                String(localized: "Trois questions suffisent pour estimer ta récupération. Avec Apple Santé, Pulse la mesure chaque matin.",
                       bundle: .module))
    }

    /// Ce qu'on annonce quand l'estimation devient disponible ou change ; `nil` tant qu'il manque une réponse.
    public static func announcement(score: Double?, category: RecoveryCategory?) -> String? {
        guard let score, score.isFinite, category != nil else { return nil }
        return estimation(score: score, category: category)
    }
}
