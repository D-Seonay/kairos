import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le petit widget Prochaine séance : horaire, intitulé, zone cible et intensités.
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
    public var accessibilityLabel: String

    public init(
        timingText: String,
        title: String,
        zoneText: String,
        activeZone: Int,
        accessibilityLabel: String
    ) {
        self.timingText = timingText
        self.title = title
        self.zoneText = zoneText
        self.activeZone = activeZone
        self.accessibilityLabel = accessibilityLabel
    }

    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> NextWorkoutWidgetContent {
        sample(at: date, calendar: calendar)
    }

    public static func sample(at date: Date, calendar: Calendar) -> NextWorkoutWidgetContent {
        let timing = String(localized: "Demain · 8:00", bundle: .module)
        let title = String(localized: "Endurance 45 min", bundle: .module)
        let zone = String(localized: "Zone 2 · 5:45 à 6:05 /km", bundle: .module)
        let spoken = String(localized: "Prochaine séance : \(timing), \(title), \(zone)", bundle: .module)
        return NextWorkoutWidgetContent(
            timingText: timing,
            title: title,
            zoneText: zone,
            activeZone: 2,
            accessibilityLabel: spoken
        )
    }
}
