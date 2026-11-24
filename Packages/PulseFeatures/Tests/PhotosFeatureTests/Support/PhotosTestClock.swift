import Foundation

/// Calendrier grégorien Europe/Paris en français, et dates locales de Paris.
enum PhotosTestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // swiftlint:disable:next force_unwrapping
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }()

    /// `"2026-08-01T18:42"` lu en heure de Paris.
    static func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        // swiftlint:disable:next force_unwrapping
        return formatter.date(from: text)!
    }
}
