import Foundation
import PulseDomain
import PulseServices

extension PlanningModel {
    /// Vrai pour un jour passé manqué de la semaine, qui a au moins un jour où se rattraper.
    public func canCatchUp(_ day: PlanningDay) -> Bool {
        !catchUpTargets(for: day).isEmpty
    }

    /// Les jours où rattraper `day` : les jours de repos à venir d'abord, puis les jours déjà chargés.
    public func catchUpTargets(for day: PlanningDay) -> [CatchUpTarget] {
        CatchUp.targets(for: day, in: days)
    }

    /// Rattrape la séance de `day` sur `target`, puis relit la semaine.
    public func catchUp(_ day: PlanningDay, on target: CatchUpTarget) async {
        do {
            try await environment.service.catchUp(day.date, on: target.day.date)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu rattraper cette séance.", bundle: .module)
        }
        catchingUp = nil
        await load()
    }

    /// « Samedi · Repos (conseillé) », « Jeudi · remplace Endurance ».
    public func catchUpLabel(of target: CatchUpTarget) -> String {
        let weekday = weekdayName(target.day.date).capitalized
        if let replaced = target.replaces {
            return String(localized: "\(weekday) · remplace \(replaced.name)", bundle: .module)
        }
        return target.isRecommended
            ? String(localized: "\(weekday) · Repos (conseillé)", bundle: .module)
            : String(localized: "\(weekday) · Repos", bundle: .module)
    }

    /// « Rattrapée samedi », ou « Rattrapée » si le jour du rattrapage n'est plus dans la semaine.
    func caughtUpDetail(of day: PlanningDay) -> String {
        let target = days.first { other in
            other.date > day.date && other.movedFrom.map { environment.calendar.isDate($0, inSameDayAs: day.date) } ?? false
        }
        guard let target else { return String(localized: "Rattrapée", bundle: .module) }
        return String(localized: "Rattrapée \(weekdayName(target.date))", bundle: .module)
    }

    /// Vrai si le jour `date` de la semaine est un jour manqué rattrapé.
    func isCaughtUp(_ date: Date) -> Bool {
        days.first { environment.calendar.isDate($0.date, inSameDayAs: date) }?.state == .caughtUp
    }
}
