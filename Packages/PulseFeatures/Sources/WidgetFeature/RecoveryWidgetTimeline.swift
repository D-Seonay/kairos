import Foundation

/// Les moments où le widget change d'allure sans que l'app l'ait rechargé.
public enum RecoveryWidgetTimeline {
    /// Maintenant, puis le début du lendemain : le score d'hier n'est pas celui d'aujourd'hui.
    /// L'extension demande ensuite une nouvelle timeline (`.atEnd`).
    public static func entryDates(now: Date, calendar: Calendar) -> [Date] {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return [now] }
        return [now, tomorrow]
    }
}
