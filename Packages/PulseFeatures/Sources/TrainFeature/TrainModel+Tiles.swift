import Foundation
import PulseDomain
import PulseServices

extension TrainModel {
    /// « Aucun programme actif » sous « Mes routines » : pas quand la lecture a échoué, l'erreur s'affiche à la place.
    var showsNoProgram: Bool {
        routines.isEmpty && errorMessage == nil
    }

    /// La tuile Musculation : « Push · ajustée · ~ 55 min », « Repos · prochaine : Pull, mardi », « Course aujourd'hui »,
    /// « Aucun programme actif ».
    var strengthSubtitle: String {
        guard let today else { return String(localized: "Séance du jour", bundle: .module) }
        switch today.plannedDay {
        case .noProgram:
            return String(localized: "Aucun programme actif", bundle: .module)
        case .rest(let next):
            guard let next else { return String(localized: "Repos aujourd'hui", bundle: .module) }
            let when = daysUntil(next.weekday) == 1 ? String(localized: "demain", bundle: .module) : next.weekday.trainName
            return String(localized: "Repos · prochaine : \(next.day.name), \(when)", bundle: .module)
        case .run:
            return String(localized: "Course aujourd'hui", bundle: .module)
        case .strength(let day):
            let active = today.activeDay ?? day
            let minutes = SessionSummary.make(day: active, directory: directory).estimatedMinutes
            let duration = String(localized: "~ \(minutes) min", bundle: .module)
            guard today.status == .adjusted else { return String(localized: "\(day.name) · \(duration)", bundle: .module) }
            return String(localized: "\(day.name) · ajustée · \(duration)", bundle: .module)
        }
    }

    /// Le nombre de jours d'aujourd'hui à `target`, de 0 à 6 ; `nil` avant la première lecture.
    func daysUntil(_ target: Weekday) -> Int? {
        guard let weekday else { return nil }
        return (target.index - weekday.index + Weekday.allCases.count) % Weekday.allCases.count
    }
}
