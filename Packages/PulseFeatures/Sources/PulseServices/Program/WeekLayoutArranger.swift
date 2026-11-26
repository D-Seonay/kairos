import Foundation
import PulseDomain

/// Fait glisser les séances d'une semaine type pour éviter les jours de repos imposés, et raccourcit une semaine à ses premières
/// routines de musculation.
public enum WeekLayoutArranger {
    /// La semaine de `program` où seules ses `count` premières routines de musculation (dans l'ordre du programme) gardent
    /// leurs jours. Les autres routines de musculation quittent la semaine mais restent dans le programme ; les courses ne
    /// bougent pas. Une routine placée plusieurs fois compte pour une.
    public static func keeping(strengthDays count: Int, of program: Program) -> [UUID?] {
        let strength = program.days.filter { $0.kind == .strength }.sorted { $0.order < $1.order }.map(\.id)
        let dropped = Set(strength.dropFirst(max(0, count)))
        return program.weekLayout.map { id in id.flatMap { dropped.contains($0) ? nil : $0 } }
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
