import Foundation

extension TrainEnvironment {
    /// `date` écrite en français dans le calendrier de l'environnement, avec les champs que `fields` ajoute au style.
    func text(of date: Date, fields: (Date.FormatStyle) -> Date.FormatStyle) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "fr_FR"), calendar: calendar,
                                     timeZone: calendar.timeZone)
        return date.formatted(fields(style))
    }
}
