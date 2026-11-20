import Foundation

/// Ce que demande « Saisir une séance passée » avant l'écran de saisie (spec M4 §19.4) : le jour, l'heure de début, la durée
/// et la routine (ou une séance vide). La séance doit être finie au moment de la saisie **(choix du constructeur)**.
public struct PastSessionDraft: Sendable, Equatable {
    public static let durationRange = 10...240
    public static let durationStep = 5
    static let defaultMinutes = 60

    /// Le jour de la séance ; seule sa date compte.
    public var day: Date
    /// L'heure de début ; seules ses heures et minutes comptent.
    public var startTime: Date
    public var durationMinutes: Int
    /// La routine du programme actif à reprendre ; `nil` pour une séance vide.
    public var routineID: UUID?

    public init(day: Date, startTime: Date, durationMinutes: Int, routineID: UUID? = nil) {
        self.day = day
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.routineID = routineID
    }

    /// Aujourd'hui, une heure avant l'heure pleine en cours, pendant une heure : à 19 h 10, de 18 h à 19 h.
    public static func initial(now: Date, calendar: Calendar) -> PastSessionDraft {
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let start = calendar.date(byAdding: .hour, value: -1, to: hour) ?? hour
        return PastSessionDraft(day: start, startTime: start, durationMinutes: defaultMinutes)
    }

    /// Le début : la date de `day` à l'heure de `startTime`.
    public func start(calendar: Calendar) -> Date? {
        let date = calendar.dateComponents([.year, .month, .day], from: day)
        let time = calendar.dateComponents([.hour, .minute], from: startTime)
        var components = DateComponents(year: date.year, month: date.month, day: date.day, hour: time.hour, minute: time.minute)
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)
    }

    /// Le début et la fin de la séance, ou `nil` si elle n'est pas encore finie à `now` (`problem(now:calendar:)` dit pourquoi).
    public func interval(now: Date, calendar: Calendar) -> DateInterval? {
        guard problem(now: now, calendar: calendar) == nil, let start = start(calendar: calendar) else { return nil }
        return DateInterval(start: start, duration: TimeInterval(durationMinutes * 60))
    }

    /// Ce qui empêche de saisir la séance, ou `nil`.
    public func problem(now: Date, calendar: Calendar) -> String? {
        guard let start = start(calendar: calendar) else {
            return String(localized: "Cette date n'existe pas.", bundle: .module)
        }
        if start >= now {
            return String(localized: "L'heure de début doit être passée.", bundle: .module)
        }
        if start.addingTimeInterval(TimeInterval(durationMinutes * 60)) > now {
            return String(localized: "La séance doit être finie : avance l'heure de début ou réduis la durée.", bundle: .module)
        }
        return nil
    }
}
