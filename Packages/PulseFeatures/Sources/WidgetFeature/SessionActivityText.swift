import Foundation
import PulseDesignSystem

/// Les textes de la Live Activity de la séance (spec M4 §15.3), sans ActivityKit : ils ne viennent que du titre, des dates, de la
/// série suivante et du compte des séries déjà présents dans l'état de l'activité (spec M4 §15.4).
public enum SessionActivityText {
    public static var restTitle: String { String(localized: "Repos", bundle: .module) }
    public static var nextSetTitle: String { String(localized: "Série suivante", bundle: .module) }

    public static var minus30Title: String { String(localized: "−30 s", bundle: .module) }
    public static var plus30Title: String { String(localized: "+30 s", bundle: .module) }
    public static var skipTitle: String { String(localized: "Passer", bundle: .module) }

    public static var minus30Label: String { String(localized: "Retirer 30 secondes de repos", bundle: .module) }
    public static var plus30Label: String { String(localized: "Ajouter 30 secondes de repos", bundle: .module) }
    public static var skipLabel: String { String(localized: "Passer le repos", bundle: .module) }

    public static var validateTitle: String { String(localized: "Valider", bundle: .module) }

    /// « Valider la série suivante : Développé couché à la barre, série 2, 70 kilos, 5 répétitions », dit par VoiceOver sur le
    /// bouton « Valider » : la série suivante n'est pas lue à part hors du titre.
    public static func validateLabel(nextSet: String?) -> String {
        guard let nextSet else { return String(localized: "Valider la série suivante", bundle: .module) }
        return String(localized: "Valider la série suivante : \(spokenNextSet(nextSet))", bundle: .module)
    }

    /// « 4 / 15 », comme « Séries » en haut de l'écran de séance.
    public static func progressText(done: Int, planned: Int) -> String {
        "\(done) / \(planned)"
    }

    /// « 4 / 15 séries », sous la barre de progression de l'écran verrouillé et de la Dynamic Island étendue.
    public static func progressCaption(done: Int, planned: Int) -> String {
        planned == 1 ? String(localized: "\(done) / 1 série", bundle: .module)
            : String(localized: "\(done) / \(planned) séries", bundle: .module)
    }

    /// « 4 séries faites sur 15 ».
    public static func progressSpoken(done: Int, planned: Int) -> String {
        done == 1 ? String(localized: "1 série faite sur \(planned)", bundle: .module)
            : String(localized: "\(done) séries faites sur \(planned)", bundle: .module)
    }

    /// Ce que VoiceOver lit pour le titre, la progression et la série suivante de l'activité. Le temps n'y est pas : le minuteur
    /// système le porte, et il reste juste pendant que l'activité est affichée. Sans série prévue, la progression n'est pas dite.
    public static func accessibilityLabel(title: String, isResting: Bool, nextSet: String?, doneSets: Int = 0,
                                          plannedSets: Int = 0) -> String {
        var parts = [isResting ? restTitle : String(localized: "Séance \(title)", bundle: .module)]
        if plannedSets > 0 {
            parts.append(progressSpoken(done: doneSets, planned: plannedSets))
        }
        if let nextSet {
            parts.append(String(localized: "série suivante : \(spokenNextSet(nextSet))", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    /// La série suivante telle que l'app la compose (« Développé couché à la barre · série 2 · 70 kg × 5 »), dite en toutes lettres :
    /// « Développé couché à la barre, série 2, 70 kilos, 5 répétitions ». Les formes des valeurs prévues : « 70 kg × 5 »,
    /// « +10 kg × 8 » (lest), « −20 kg × 6 » (assistance), « 70 kg × 45 s », « 70 kg », « 8 rép. », « 30 s ». Un morceau qu'on ne
    /// reconnaît pas reste tel quel.
    public static func spokenNextSet(_ nextSet: String) -> String {
        nextSet.components(separatedBy: " · ").map(spokenValues).joined(separator: ", ")
    }

    private static func spokenValues(_ text: String) -> String {
        let sides = text.components(separatedBy: " × ")
        guard sides.count <= 2 else { return text }
        let spoken = sides.enumerated().map { index, side in index == 0 && sides.count == 2 ? spokenLoad(side) : spokenQuantity(side) }
        return spoken.contains(nil) ? text : spoken.compactMap { $0 }.joined(separator: ", ")
    }

    /// « 70 kg » donne « 70 kilos », « +10 kg » « plus 10 kilos », « −20 kg » « moins 20 kilos ».
    private static func spokenLoad(_ text: String) -> String? {
        guard let match = text.wholeMatch(of: /([+−])?(\d+(?:[.,]\d+)?) kg/),
              let value = Double(match.2.replacing(",", with: ".")) else { return nil }
        let kilos = PulseSpoken.kilos(value)
        switch match.1 {
        case "+": return String(localized: "plus \(kilos)", bundle: .module)
        case "−": return String(localized: "moins \(kilos)", bundle: .module)
        default: return kilos
        }
    }

    /// « 5 » ou « 8 rép. » donnent des répétitions, « 45 s » des secondes, « 70 kg » des kilos (charge seule).
    private static func spokenQuantity(_ text: String) -> String? {
        if let load = spokenLoad(text) { return load }
        if let match = text.wholeMatch(of: /(\d+) s/), let seconds = Int(match.1) {
            return PulseSpoken.duration(seconds: seconds)
        }
        if let match = text.wholeMatch(of: /(\d+)(?: rép\.)?/), let reps = Int(match.1) {
            return PulseSpoken.repetitions(reps)
        }
        return nil
    }
}
