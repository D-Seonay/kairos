import Foundation
import PulseDomain
import PulseServices

/// Compléments, prises et séances pour les tests des compléments ; le 20 novembre 2026 est un vendredi.
enum SupplementFixtures {
    static let created = TestClock.date("2026-10-01T08:00")

    static func supplement(_ name: String = "Créatine", timing: SupplementTiming = .fixedTime, minutes: Int? = 8 * 60,
                           days: SupplementDays = .everyDay, weekdays: [Weekday] = [], unit: DoseUnit = .gram,
                           dose: Double = 5, stock: Double? = nil, threshold: Double? = nil, reminder: Bool = true,
                           health: SupplementHealthType? = nil, order: Int = 0, created: Date = created) -> Supplement {
        Supplement(name: name, form: .powder, dose: dose, unit: unit, timing: timing, timeOfDayMinutes: minutes, days: days,
                   customWeekdays: weekdays, stockDoses: stock, lowStockThreshold: threshold, reminderEnabled: reminder,
                   healthKitType: health?.rawValue, order: order, createdAt: created, updatedAt: created)
    }

    static func intake(of supplement: Supplement, at text: String) -> SupplementIntake {
        let date = TestClock.date(text)
        return SupplementIntake(supplementID: supplement.id, takenAt: date, dose: supplement.dose, createdAt: date, updatedAt: date)
    }

    static func session(start: String, end: String? = nil, status: SessionStatus = .completed,
                        kind: SessionKind = .strength) -> WorkoutSession {
        let startDate = TestClock.date(start)
        return WorkoutSession(startedAt: startDate, endedAt: end.map(TestClock.date), kind: kind, source: .pulse, status: status,
                              title: "Push", createdAt: startDate, updatedAt: startDate)
    }

    static func schedule(_ supplements: [Supplement], intakes: [SupplementIntake] = [],
                         training: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday],
                         sessions: [WorkoutSession] = []) -> SupplementSchedule {
        SupplementSchedule(supplements: supplements, intakes: intakes, trainingWeekdays: training, sessions: sessions,
                           calendar: TestClock.calendar)
    }

    /// Un programme Push Pull Legs Push Pull du lundi au vendredi.
    static func program() -> Program {
        let push = RoutineDay(order: 0, name: "Push", kind: .strength)
        let pull = RoutineDay(order: 1, name: "Pull", kind: .strength)
        let legs = RoutineDay(order: 2, name: "Legs", kind: .strength)
        return Program(name: "PPL", sessionsPerWeek: 5, weekLayout: [push.id, pull.id, legs.id, push.id, pull.id, nil, nil],
                       days: [push, pull, legs], createdAt: created, updatedAt: created)
    }
}
