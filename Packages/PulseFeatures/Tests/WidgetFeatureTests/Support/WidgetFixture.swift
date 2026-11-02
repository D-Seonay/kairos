// swiftlint:disable force_unwrapping
import Foundation
import PulseDomain

/// Calendrier grégorien Europe/Paris en français et dates locales de Paris.
enum WidgetClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)!
    }
}

enum WidgetSample {
    /// Le lundi 2 novembre : 58, fatigue modérée, « Push », séance allégée.
    static func snapshot(isEstimated: Bool = false, sessionTitle: String? = "Push", isLightened: Bool = true) -> WidgetSnapshot {
        WidgetSnapshot(day: WidgetClock.date("2026-11-02T00:00"), score: 58, category: .moderateFatigue,
                       isEstimated: isEstimated, sessionTitle: sessionTitle, isLightened: isLightened)
    }
}
// swiftlint:enable force_unwrapping
