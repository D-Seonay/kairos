import Foundation
import PulseDesignSystem
import PulseDomain

/// Les données affichées par le petit widget Charge (ACWR) : ratio, zone d'entraînement et jauge linéaire.
public struct LoadWidgetContent: Sendable, Equatable {
    public static let kind = "LoadWidget"

    public static var displayName: String {
        String(localized: "Charge", bundle: .module)
    }

    public static var summary: String {
        String(localized: "Ton ratio de charge aiguë sur chronique (ACWR).", bundle: .module)
    }

    public var ratio: Double
    public var ratioText: String
    public var zoneText: String
    public var isOptimal: Bool
    public var accessibilityLabel: String

    public init(
        ratio: Double,
        ratioText: String,
        zoneText: String,
        isOptimal: Bool,
        accessibilityLabel: String
    ) {
        self.ratio = ratio
        self.ratioText = ratioText
        self.zoneText = zoneText
        self.isOptimal = isOptimal
        self.accessibilityLabel = accessibilityLabel
    }

    public static func make(snapshot: WidgetSnapshot?, at date: Date, calendar: Calendar) -> LoadWidgetContent {
        sample(at: date, calendar: calendar)
    }

    public static func sample(at date: Date, calendar: Calendar) -> LoadWidgetContent {
        let ratio = 1.12
        let ratioString = "1,12"
        let zone = String(localized: "Zone optimale", bundle: .module)
        let label = String(localized: "Charge d'entraînement \(ratioString), \(zone)", bundle: .module)
        return LoadWidgetContent(
            ratio: ratio,
            ratioText: ratioString,
            zoneText: zone,
            isOptimal: true,
            accessibilityLabel: label
        )
    }
}
