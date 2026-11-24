import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le widget Prochaine séance : horaire, intitulé, zone cible et intensités.
public struct NextWorkoutWidgetContent: Sendable, Equatable {
    public static let kind = "NextWorkoutWidget"

    public static var displayName: String {
        String(localized: "Prochaine séance", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ta prochaine séance prévue dans ton programme.", bundle: .module)
    }

    public var timingText: String
    public var title: String
    public var zoneText: String
    public var activeZone: Int
    public var inlineText: String
    public var accessibilityLabel: String

    public init(
        timingText: String,
        title: String,
        zoneText: String,
        activeZone: Int,
        inlineText: String,
        accessibilityLabel: String
    ) {
        self.timingText = timingText
        self.title = title
        self.zoneText = zoneText
        self.activeZone = activeZone
        self.inlineText = inlineText
        self.accessibilityLabel = accessibilityLabel
    }

    /// « Prochaine séance : Samedi, Endurance, Sortie facile, 45 minutes » : seules les parties non vides sont dites, sans virgule
    /// finale quand le détail manque.
    static func spokenLabel(timing: String, title: String, detail: String) -> String {
        let parts = [timing, title, detail].filter { !$0.isEmpty }.joined(separator: ", ")
        return String(localized: "Prochaine séance : \(parts)", bundle: .module)
    }

    /// La prochaine séance de l'instantané du jour. Sans instantané du jour ou sans semaine, le widget le dit au lieu d'inventer
    /// une séance.
    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> NextWorkoutWidgetContent {
        guard let planning = WidgetPlanningText.planning(snapshot, at: date, calendar: calendar) else { return notReady }
        guard let next = planning.snapshot.nextSession else {
            let title = String(localized: "Rien de prévu", bundle: .module)
            let detail = String(localized: "Cette semaine", bundle: .module)
            return NextWorkoutWidgetContent(timingText: detail, title: title, zoneText: "", activeZone: 0, inlineText: title,
                                            accessibilityLabel: String(localized: "Aucune séance prévue cette semaine", bundle: .module))
        }
        let timing = WidgetPlanningText.timing(of: next.date, from: date, calendar: calendar)
        let detail = next.detail ?? ""
        let spoken = spokenLabel(timing: timing, title: next.title, detail: WidgetPlanningText.spokenDetail(detail))
        return NextWorkoutWidgetContent(timingText: timing, title: next.title, zoneText: detail,
                                        activeZone: 0, inlineText: "\(next.title) · \(timing)",
                                        accessibilityLabel: spoken)
    }

    /// Pas encore d'instantané du jour : une invitation à ouvrir l'app.
    static var notReady: NextWorkoutWidgetContent {
        let title = String(localized: "Pas encore prête", bundle: .module)
        return NextWorkoutWidgetContent(
            timingText: displayName, title: title, zoneText: String(localized: "Ouvre Pulse pour la charger", bundle: .module),
            activeZone: 0, inlineText: String(localized: "Prochaine séance pas encore prête", bundle: .module),
            accessibilityLabel: String(localized: "Prochaine séance pas encore prête. Ouvre Pulse pour la charger", bundle: .module))
    }

    /// Un exemple, pour la galerie de widgets et le gabarit avant le premier chargement.
    public static func sample(at date: Date, calendar: Calendar) -> NextWorkoutWidgetContent {
        let timing = String(localized: "Demain · 8:00", bundle: .module)
        let title = String(localized: "Endurance 45 min", bundle: .module)
        let zone = String(localized: "Zone 2 · 5:45 à 6:05 /km", bundle: .module)
        let spoken = spokenLabel(
            timing: String(localized: "Demain, \(PulseSpoken.clock(hour: 8, minute: 0))", bundle: .module),
            title: String(localized: "Endurance 45 minutes", bundle: .module),
            detail: String(localized: "zone 2, \(WidgetPlanningText.spokenPace(fastest: 345, slowest: 365))", bundle: .module)
        )
        let inline = "\(title) · \(timing)"
        return NextWorkoutWidgetContent(
            timingText: timing,
            title: title,
            zoneText: zone,
            activeZone: 2,
            inlineText: inline,
            accessibilityLabel: spoken
        )
    }
}
