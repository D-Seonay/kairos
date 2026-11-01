import Foundation
import PulseDomain

/// Fait glisser les séances d'une semaine type pour éviter les jours de repos imposés.
public enum WeekLayoutArranger {
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
