import Foundation
import PulseDomain

extension Weekday {
    /// Le jour de la semaine de `date` dans `calendar`.
    public init(date: Date, calendar: Calendar) {
        // `Calendar.component(.weekday, …)` : dimanche = 1, lundi = 2, … samedi = 7.
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        self = Self.allCases[index]
    }

    /// Position dans la semaine, lundi = 0.
    public var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}
