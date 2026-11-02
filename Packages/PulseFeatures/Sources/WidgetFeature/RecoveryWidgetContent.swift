import Foundation
import PulseDesignSystem
import PulseDomain

/// Ce que le widget écrit, calculé une fois pour toutes ses tailles : la maison, l'écran verrouillé, VoiceOver.
public struct RecoveryWidgetContent: Sendable, Equatable {
    public static let kind = "RecoveryWidget"

    public static var displayName: String {
        String(localized: "Récupération", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ton score du matin et ta séance du jour.", bundle: .module)
    }

    /// `nil` tant que le score du jour n'est pas prêt.
    public var score: Int?
    public var category: RecoveryCategory?
    /// Le nom de la catégorie, suivi de « · estimé » quand le score l'est ; jamais porté par la seule couleur.
    public var categoryText: String
    /// La séance du jour, en une ligne ; `nil` sans score.
    public var footer: String?
    /// Une ligne pour le widget en ligne de l'écran verrouillé : « 58 · fatigue modérée ».
    public var inlineText: String
    public var accessibilityLabel: String

    /// L'instantané compte pour le jour de `date` seulement : le lendemain matin, le score d'hier ne reste pas affiché.
    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> RecoveryWidgetContent {
        guard let snapshot, calendar.isDate(snapshot.day, inSameDayAs: date) else { return notReady }
        let name = snapshot.category.localizedName
        let footer = footer(for: snapshot)
        var spoken = [String(localized: "Récupération \(snapshot.score) sur 100", bundle: .module), name.lowercased()]
        if snapshot.isEstimated { spoken.append(String(localized: "estimé", bundle: .module)) }
        spoken.append(footer.lowercased())
        return RecoveryWidgetContent(
            score: snapshot.score, category: snapshot.category,
            categoryText: snapshot.isEstimated ? String(localized: "\(name) · estimé", bundle: .module) : name,
            footer: footer,
            inlineText: String(localized: "\(snapshot.score) · \(name.lowercased())", bundle: .module),
            accessibilityLabel: spoken.joined(separator: ", "))
    }

    /// Un exemple, pour la galerie de widgets et le gabarit avant le premier chargement.
    public static func sample(at date: Date, calendar: Calendar) -> RecoveryWidgetContent {
        let snapshot = WidgetSnapshot(day: date, score: 58, category: .moderateFatigue, isEstimated: false,
                                      sessionTitle: "Push", isLightened: true)
        return make(snapshot: snapshot, at: date, calendar: calendar)
    }

    private static var notReady: RecoveryWidgetContent {
        let text = String(localized: "Score pas encore prêt", bundle: .module)
        return RecoveryWidgetContent(score: nil, category: nil, categoryText: text, footer: nil, inlineText: text,
                                     accessibilityLabel: String(localized: "Récupération : score pas encore prêt", bundle: .module))
    }

    private static func footer(for snapshot: WidgetSnapshot) -> String {
        guard snapshot.sessionTitle != nil else { return String(localized: "Pas de séance aujourd'hui", bundle: .module) }
        return snapshot.isLightened ? String(localized: "Séance allégée", bundle: .module)
            : String(localized: "Séance normale", bundle: .module)
    }
}
