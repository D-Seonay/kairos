import Foundation
import PulseDomain

/// Un jour où une séance manquée peut être rattrapée.
public struct CatchUpTarget: Sendable, Equatable, Identifiable {
    public var day: PlanningDay
    /// La séance prévue ce jour-là, que le rattrapage remplace ; `nil` un jour de repos.
    public var replaces: RoutineDay?
    /// Le premier jour de repos à venir : le rattrapage n'y prend la place d'aucune séance.
    public var isRecommended: Bool

    public init(day: PlanningDay, replaces: RoutineDay?, isRecommended: Bool) {
        self.day = day
        self.replaces = replaces
        self.isRecommended = isRecommended
    }

    public var id: Date { day.id }
}

/// Rattraper une séance manquée de la semaine en cours sur un jour à venir de la même semaine.
///
/// Le jour cible reçoit une ligne `.user` portant la séance manquée, son origine dans `movedFromDate`. Le jour manqué garde sa
/// séance dans une ligne `.user` au statut `.skipped` : c'est elle qui le montre « Rattrapée ». Les autres jours ne bougent pas,
/// la semaine type reprend après le rattrapage, et « Rétablir la semaine type » efface les deux lignes.
public enum CatchUp {
    /// Un jour passé, prévu, sans séance qui le valide, et pas encore rattrapé.
    public static func canCatchUp(_ day: PlanningDay) -> Bool {
        day.state == .missed && day.isPast && day.routine != nil
    }

    /// Les jours de `week` où rattraper `source` : aujourd'hui ou plus tard, pas encore validés, hors repos imposés ; les jours
    /// de repos d'abord, puis les jours déjà chargés, chacun dans l'ordre de la semaine.
    public static func targets(for source: PlanningDay, in week: [PlanningDay]) -> [CatchUpTarget] {
        guard canCatchUp(source) else { return [] }
        let open = week.filter { $0.date > source.date && $0.isMovable && $0.state != .mandatoryRest }
            .sorted { $0.date < $1.date }
        let rest = open.filter { $0.routine == nil }
        let loaded = open.filter { $0.routine != nil }
        return rest.enumerated().map { index, day in CatchUpTarget(day: day, replaces: nil, isRecommended: index == 0) }
            + loaded.map { CatchUpTarget(day: $0, replaces: $0.routine, isRecommended: false) }
    }

    /// Les deux lignes qu'un rattrapage écrit : la séance de `source` sur `target`, et `source` marqué rattrapé. Elles
    /// reprennent les lignes existantes de ces jours.
    public static func lines(source: PlanningDay, target: PlanningDay, programID: UUID, now: Date)
        -> (source: ScheduledDay, target: ScheduledDay) {
        let routine = source.routine
        let kind = PlanningService.kind(of: routine)
        let title = routine?.name ?? ""
        var caughtUp = source.scheduled ?? ScheduledDay(date: source.date, title: title, kind: kind, status: .skipped,
                                                        createdAt: now, updatedAt: now)
        caughtUp.programID = programID
        caughtUp.routineDayID = routine?.id
        caughtUp.title = title
        caughtUp.kind = kind
        caughtUp.status = .skipped
        caughtUp.moveReason = .user
        caughtUp.moveReasonText = nil
        caughtUp.updatedAt = now
        var moved = target.scheduled ?? ScheduledDay(date: target.date, title: title, kind: kind, status: .planned,
                                                     createdAt: now, updatedAt: now)
        moved.programID = programID
        moved.routineDayID = routine?.id
        moved.title = title
        moved.kind = kind
        moved.status = .planned
        moved.movedFromDate = source.date
        moved.moveReason = .user
        moved.moveReasonText = nil
        moved.updatedAt = now
        return (caughtUp, moved)
    }

    /// Vrai pour la ligne d'un jour dont la séance a été rattrapée un autre jour.
    public static func isCaughtUp(_ line: ScheduledDay?) -> Bool {
        line?.status == .skipped && line?.moveReason == .user
    }
}
