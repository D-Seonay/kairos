import Foundation

/// Les textes de la Live Activity de la séance (spec M4 §15.3), sans ActivityKit : ils ne viennent que du titre, des dates et de la
/// série suivante déjà présents dans l'état de l'activité (spec M4 §15.4).
public enum SessionActivityText {
    public static var restTitle: String { String(localized: "Repos", bundle: .module) }
    public static var nextSetTitle: String { String(localized: "Série suivante", bundle: .module) }

    public static var minus30Title: String { String(localized: "−30 s", bundle: .module) }
    public static var plus30Title: String { String(localized: "+30 s", bundle: .module) }
    public static var skipTitle: String { String(localized: "Passer", bundle: .module) }

    public static var minus30Label: String { String(localized: "Retirer 30 secondes de repos", bundle: .module) }
    public static var plus30Label: String { String(localized: "Ajouter 30 secondes de repos", bundle: .module) }
    public static var skipLabel: String { String(localized: "Passer le repos", bundle: .module) }

    /// Ce que VoiceOver lit pour le titre et la série suivante de l'activité. Le temps n'y est pas : le minuteur système le porte, et
    /// il reste juste pendant que l'activité est affichée.
    public static func accessibilityLabel(title: String, isResting: Bool, nextSet: String?) -> String {
        var parts = [isResting ? restTitle : String(localized: "Séance \(title)", bundle: .module)]
        if let nextSet {
            parts.append(String(localized: "série suivante : \(nextSet)", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }
}
