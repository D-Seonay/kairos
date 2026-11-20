import Foundation
import PulseDomain

/// Les rappels de compléments à planifier (spec M5 §7) : une notification ponctuelle par complément et par jour dû, sur les
/// 14 prochains jours, jamais dans le passé ni pour un complément déjà pris ce jour-là.
public enum SupplementReminderPlanner {
    public static let horizonDays = 14
    /// iOS garde 64 notifications en attente : les rappels en prennent au plus 48, le reste de l'app garde de la place.
    public static let maximumCount = 48
    /// Délai du rappel « après la séance », après la fin réelle de la séance.
    public static let afterWorkoutDelayMinutes = 45

    public static func reminders(schedule: SupplementSchedule, now: Date, enabled: Bool) -> [SupplementReminder] {
        guard enabled else { return [] }
        let calendar = schedule.calendar
        let today = calendar.startOfDay(for: now)
        var reminders: [SupplementReminder] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            for item in schedule.items(on: day) where item.supplement.reminderEnabled && !item.isTaken {
                guard let fire = fireDate(of: item, on: day, schedule: schedule), fire > now else { continue }
                reminders.append(SupplementReminder(supplementID: item.supplement.id, day: day, fireDate: fire,
                                                    title: item.supplement.name,
                                                    body: SupplementText.reminderBody(item.supplement)))
            }
        }
        return Array(reminders.sorted { $0.fireDate < $1.fireDate }.prefix(maximumCount))
    }

    /// L'heure du rappel ; `nil` pour « avant la séance » un jour de repos, et pour « après la séance » tant qu'elle n'est pas finie.
    static func fireDate(of item: SupplementDueItem, on day: Date, schedule: SupplementSchedule) -> Date? {
        let calendar = schedule.calendar
        switch item.supplement.timing {
        case .fixedTime, .bedtime:
            return calendar.date(byAdding: .minute, value: item.plannedMinutes, to: day)
        case .beforeWorkout:
            guard schedule.isTrainingDay(day) else { return nil }
            return calendar.date(byAdding: .minute, value: item.plannedMinutes, to: day)
        case .afterWorkout:
            guard let end = schedule.workoutEnd(on: day) else { return nil }
            return calendar.date(byAdding: .minute, value: afterWorkoutDelayMinutes, to: end)
        }
    }
}
