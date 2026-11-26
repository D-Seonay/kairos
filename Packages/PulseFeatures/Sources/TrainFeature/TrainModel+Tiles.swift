import Foundation
import PulseDomain
import PulseServices

extension TrainModel {
    /// « Aucun programme actif » sous « Mes routines » : pas avant la première lecture, qui n'en sait encore rien, ni quand la
    /// lecture a échoué, l'erreur s'affiche à la place.
    var showsNoProgram: Bool {
        hasLoaded && routines.isEmpty && errorMessage == nil
    }

    /// La tuile Musculation : « Push · ajustée · ~ 55 min », « Repos · prochaine : Pull, mardi », « Course aujourd'hui »,
    /// « Aucun programme actif ».
    public var strengthSubtitle: String {
        strengthSubtitle(spoken: false)
    }

    /// La même ligne dite en mots, sans « · » ni « ~ » : « Push, ajustée, environ 55 minutes ».
    public var strengthSubtitleSpoken: String {
        strengthSubtitle(spoken: true)
    }

    private func strengthSubtitle(spoken: Bool) -> String {
        guard let today else { return String(localized: "Séance du jour", bundle: .module) }
        let separator = spoken ? ", " : " · "
        switch today.plannedDay {
        case .noProgram:
            return String(localized: "Aucun programme actif", bundle: .module)
        case .rest(let next):
            guard let next else { return String(localized: "Repos aujourd'hui", bundle: .module) }
            let when = daysUntil(next.weekday) == 1 ? String(localized: "demain", bundle: .module) : next.weekday.trainName
            return spoken ? String(localized: "Repos, prochaine : \(next.day.name), \(when)", bundle: .module)
                : String(localized: "Repos · prochaine : \(next.day.name), \(when)", bundle: .module)
        case .run:
            return String(localized: "Course aujourd'hui", bundle: .module)
        case .strength(let day):
            let active = today.activeDay ?? day
            let minutes = SessionSummary.make(day: active, directory: directory).estimatedMinutes
            let duration = spoken ? TrainText.approximateMinutes(minutes) : String(localized: "~ \(minutes) min", bundle: .module)
            var parts = [day.name]
            if today.status == .adjusted { parts.append(String(localized: "ajustée", bundle: .module)) }
            parts.append(duration)
            return parts.joined(separator: separator)
        }
    }

    /// La tuile Course : « Sortie facile · aujourd'hui », « Fractionné · prévue demain », « Sortie longue · prévue samedi », et
    /// « prévue mercredi prochain » pour la course du même jour la semaine suivante. « Course du jour » avant la première lecture,
    /// comme « Séance du jour » sur la tuile Musculation.
    public var runSubtitle: String {
        guard hasLoaded else { return String(localized: "Course du jour", bundle: .module) }
        guard let nextRun else { return String(localized: "Aucune course au programme", bundle: .module) }
        let title = nextRun.day.runType?.localizedName ?? nextRun.day.name
        let day = nextRun.weekday.trainName
        switch nextRunDaysAhead {
        case 0: return String(localized: "\(title) · aujourd'hui", bundle: .module)
        case 1: return String(localized: "\(title) · prévue demain", bundle: .module)
        case Weekday.allCases.count: return String(localized: "\(title) · prévue \(day) prochain", bundle: .module)
        default: return String(localized: "\(title) · prévue \(day)", bundle: .module)
        }
    }

    /// Ce que dit le bouton « Courir » à VoiceOver : la course du jour ou une course libre, d'après ce que `runLaunch()` lance.
    var runStartLabel: String {
        runLaunchIsPlanned
            ? String(localized: "Lancer la course du jour", bundle: .module)
            : String(localized: "Lancer une course libre", bundle: .module)
    }

    /// Le nombre de jours d'aujourd'hui à `target`, de 0 à 6 ; `nil` avant la première lecture.
    func daysUntil(_ target: Weekday) -> Int? {
        guard let weekday else { return nil }
        return (target.index - weekday.index + Weekday.allCases.count) % Weekday.allCases.count
    }
}
