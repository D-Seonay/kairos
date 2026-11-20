import Foundation
import PulseDomain

/// La régularité d'un complément sur 30 jours (spec M5 §8) : jours pris sur jours dus, depuis sa création. Aujourd'hui ne
/// compte que s'il est déjà pris.
public struct SupplementRegularity: Sendable, Equatable {
    public static let windowDays = 30

    public var takenDays: Int
    public var dueDays: Int

    public init(takenDays: Int, dueDays: Int) {
        self.takenDays = takenDays
        self.dueDays = dueDays
    }

    /// De 0 à 1 ; `nil` quand aucun jour n'était dû.
    public var rate: Double? {
        dueDays > 0 ? Double(takenDays) / Double(dueDays) : nil
    }

    public static func compute(for supplement: Supplement, schedule: SupplementSchedule, today: Date) -> SupplementRegularity {
        let calendar = schedule.calendar
        let todayStart = calendar.startOfDay(for: today)
        var taken = 0
        var due = 0
        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart),
                  schedule.isDue(supplement, on: day) else { continue }
            let isTaken = schedule.latestIntake(of: supplement.id, on: day) != nil
            if offset == 0 && !isTaken { continue }
            due += 1
            if isTaken { taken += 1 }
        }
        return SupplementRegularity(takenDays: taken, dueDays: due)
    }
}
