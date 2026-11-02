import Foundation

/// Ce que le widget et l'écran verrouillé savent du jour : jamais une valeur de santé brute.
public struct WidgetSnapshot: Sendable, Equatable, Codable {
    public var day: Date
    public var score: Int
    public var category: RecoveryCategory
    public var isEstimated: Bool
    public var sessionTitle: String?
    public var isLightened: Bool

    public init(day: Date, score: Int, category: RecoveryCategory, isEstimated: Bool, sessionTitle: String?, isLightened: Bool) {
        self.day = day
        self.score = score
        self.category = category
        self.isEstimated = isEstimated
        self.sessionTitle = sessionTitle
        self.isLightened = isLightened
    }
}
