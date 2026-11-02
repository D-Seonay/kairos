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

    /// Ce que VoiceOver lit pour toute l'activité : le repos restant et la série suivante, ou le titre de la séance hors repos.
    /// Un repos dont la date est passée compte comme hors repos.
    public static func accessibilityLabel(title: String, restEndsAt: Date?, nextSet: String?, now: Date) -> String {
        var parts: [String]
        if let restEndsAt, restEndsAt > now {
            let left = String(localized: "\(spokenDuration(restEndsAt.timeIntervalSince(now))) restantes", bundle: .module)
            parts = [restTitle, left]
        } else {
            parts = [String(localized: "Séance \(title)", bundle: .module)]
        }
        if let nextSet {
            parts.append(String(localized: "série suivante : \(nextSet)", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    /// « 1 minute et 52 secondes », « 45 secondes » : arrondi à la seconde supérieure, comme le minuteur système.
    private static func spokenDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let (minutes, seconds) = total.quotientAndRemainder(dividingBy: 60)
        let style = { (unit: Duration.UnitsFormatStyle.Unit, value: Int) in
            Duration.seconds(value * (unit == .minutes ? 60 : 1))
                .formatted(.units(allowed: [unit], width: .wide).locale(Locale(identifier: "fr_FR")))
                .replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
        }
        switch (minutes, seconds) {
        case (0, _): return style(.seconds, seconds)
        case (_, 0): return style(.minutes, minutes)
        default: return String(localized: "\(style(.minutes, minutes)) et \(style(.seconds, seconds))", bundle: .module)
        }
    }
}
