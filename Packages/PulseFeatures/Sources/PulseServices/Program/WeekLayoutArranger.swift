import Foundation
import PulseDomain

/// Fait glisser les séances d'une semaine type pour éviter les jours de repos imposés, et raccourcit une semaine à ses premières
/// routines de musculation.
public enum WeekLayoutArranger {
    /// La semaine de `program` où seules ses `count` premières routines de musculation (dans l'ordre du programme) restent.
    /// Les autres routines de musculation quittent la semaine mais restent dans le programme ; les courses ne bougent pas.
    /// Une routine placée plusieurs fois compte pour une.
    ///
    /// Les routines gardées se répartissent sur les jours que la musculation occupait, du premier au dernier : Full Body A
    /// lundi et B vendredi, pas lundi et mercredi suivis de quatre jours vides. Quand une routine est placée plusieurs fois,
    /// ou qu'une routine de musculation n'est pas dans la semaine, rien n'est réparti : les routines gardées gardent leurs
    /// jours.
    public static func keeping(strengthDays count: Int, of program: Program) -> [UUID?] {
        let strength = program.days.filter { $0.kind == .strength }.sorted { $0.order < $1.order }.map(\.id)
        let kept = Array(strength.prefix(max(0, count)))
        let dropped = Set(strength.dropFirst(max(0, count)))
        var layout = program.weekLayout.map { id in id.flatMap { dropped.contains($0) ? nil : $0 } }
        let slots = program.weekLayout.indices.filter { index in program.weekLayout[index].map(strength.contains) ?? false }
        let placedOnce = Set(slots.compactMap { program.weekLayout[$0] }).count == slots.count
        guard !dropped.isEmpty, !kept.isEmpty, placedOnce, slots.count == strength.count else { return layout }
        for index in slots { layout[index] = nil }
        for (position, id) in kept.enumerated() {
            layout[slots[spread(position, of: kept.count, over: slots.count)]] = id
        }
        return layout
    }

    /// Le rang, parmi `slots` jours, de la séance `position` sur `count` : la première sur le premier jour, la dernière sur
    /// le dernier, les autres à intervalles réguliers. Une seule séance prend le premier jour.
    static func spread(_ position: Int, of count: Int, over slots: Int) -> Int {
        guard count > 1 else { return 0 }
        return Int((Double(position) * Double(slots - 1) / Double(count - 1)).rounded())
    }

    /// Parcourt lundi → dimanche : chaque séance prend le premier jour libre et non imposé en repos à partir de son jour,
    /// en bouclant sur la semaine. Sans place, elle quitte la semaine.
    public static func arrange(_ layout: [UUID?], restWeekdays: [Weekday]) -> [UUID?] {
        let count = layout.count
        let restIndices = Set(restWeekdays.compactMap { Weekday.allCases.firstIndex(of: $0) })
        var arranged = [UUID?](repeating: nil, count: count)
        for (index, session) in layout.enumerated() {
            guard let session else { continue }
            let slot = (0..<count).lazy
                .map { (index + $0) % count }
                .first { arranged[$0] == nil && !restIndices.contains($0) }
            if let slot { arranged[slot] = session }
        }
        return arranged
    }
}
