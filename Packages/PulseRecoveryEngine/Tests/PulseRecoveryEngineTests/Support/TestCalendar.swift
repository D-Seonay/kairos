import Foundation

/// Calendrier grégorien en fuseau Europe/Paris, partagé par les tests du moteur.
enum TestCalendar {
    static let paris: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    /// Minuit local du jour donné.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        date(year, month, day, 0, 0)
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        paris.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// `day` décalé de `offset` jours (négatif vers le passé), via le calendrier.
    static func shift(_ day: Date, by offset: Int) -> Date {
        paris.date(byAdding: .day, value: offset, to: day)!
    }
}
