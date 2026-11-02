import Foundation

/// Lit les dates de l'export Hevy : `d MMM yyyy, HH:mm`, mois en français (`oct.`, `févr.`, `août`…) ou en anglais (`Oct`, `Feb`…).
public enum HevyDate {
    private static let months: [String: Int] = [
        "janv": 1, "jan": 1, "févr": 2, "feb": 2, "mars": 3, "mar": 3, "avr": 4, "apr": 4, "mai": 5, "may": 5,
        "juin": 6, "jun": 6, "juil": 7, "jul": 7, "août": 8, "aug": 8, "sept": 9, "sep": 9, "oct": 10,
        "nov": 11, "déc": 12, "dec": 12
    ]

    /// Assemble les composants avec `calendar.date(from:)` dans le fuseau du calendrier : une heure inexistante (passage à l'heure
    /// d'été) donne l'heure valide suivante, une heure ambiguë (retour à l'heure d'hiver) sa première occurrence.
    public static func parse(_ text: String, calendar: Calendar) -> Date? {
        let halves = text.trimmingCharacters(in: .whitespaces).components(separatedBy: ",")
        guard halves.count == 2 else { return nil }
        let day = halves[0].split(separator: " ", omittingEmptySubsequences: true)
        let time = halves[1].trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard day.count == 3, time.count == 2,
              let dayNumber = number(day[0], in: 1...31), let month = months[monthKey(day[1])],
              let year = number(day[2], in: 1...9999), day[2].count == 4,
              let hour = number(time[0], in: 0...23), let minute = number(time[1], in: 0...59), time[1].count == 2
        else { return nil }
        let components = DateComponents(year: year, month: month, day: dayNumber, hour: hour, minute: minute)
        guard let date = calendar.date(from: components) else { return nil }
        // Un 31 février ne se décale pas sur le mois suivant : la date lue doit retomber sur le même jour.
        let read = calendar.dateComponents([.year, .month, .day], from: date)
        return read.year == year && read.month == month && read.day == dayNumber ? date : nil
    }

    private static func monthKey(_ text: Substring) -> String {
        let name = text.lowercased()
        return name.hasSuffix(".") ? String(name.dropLast()) : name
    }

    private static func number(_ text: Substring, in range: ClosedRange<Int>) -> Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text), range.contains(value) else {
            return nil
        }
        return value
    }
}
