// swiftlint:disable force_unwrapping
import Foundation
import PulseRecoveryEngine

/// Calendrier grégorien Europe/Paris en français, et dates locales de Paris, partagés par les tests de services.
enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// `"2026-11-02T08:00"` lu en heure de Paris.
    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: text)!
    }
}

extension RecoveryOutcome {
    var measured: RecoveryResult? {
        if case .measured(let result) = self { result } else { nil }
    }

    var isCheckIn: Bool {
        if case .needsCheckIn = self { true } else { false }
    }
}
// swiftlint:enable force_unwrapping
