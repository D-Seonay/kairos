import Foundation
import PulseDomain

/// Les rappels de coucher à planifier : un par soir, d'aujourd'hui à J+6, jamais dans le passé ni hors de 18:00 … 03:00.
/// Pur : les heures viennent du calendrier donné.
public enum BedtimeReminderPlanner {
    public static let horizonEvenings = 7

    /// `sessionName(jour)` : le nom de la séance prévue ce jour-là, `nil` un jour de repos. `lastNightAsleepMinutes` : la nuit
    /// qui finit aujourd'hui ; elle ne compte que pour le rappel de ce soir.
    public static func reminders(plan: SleepPlan, lastNightAsleepMinutes: Int?, sessionName: (Date) -> String?, now: Date,
                                 calendar: Calendar) -> [BedtimeReminder] {
        guard plan.reminderEnabled else { return [] }
        let today = calendar.startOfDay(for: now)
        let shortNight = lastNightAsleepMinutes.flatMap {
            SleepGoal.isShortNight(asleepMinutes: $0, goalMinutes: plan.goalMinutes) ? $0 : nil
        }
        return (0..<horizonEvenings).compactMap { offset -> BedtimeReminder? in
            guard let evening = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = plan.reminderDate(onEvening: evening, calendar: calendar), fire > now,
                  let bedtime = plan.bedtime(onEvening: evening, calendar: calendar),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening),
                  let wake = plan.wakeMinutes(weekend: SleepPlan.wakesOnWeekend(afterEvening: evening, calendar: calendar))
            else { return nil }
            let body = BedtimeReminderText.body(goalMinutes: plan.goalMinutes, wakeMinutes: wake,
                                                shortNightMinutes: offset == 0 ? shortNight : nil,
                                                sessionName: sessionName(tomorrow))
            return BedtimeReminder(evening: evening, fireDate: fire,
                                   title: BedtimeReminderText.title(bedtime: bedtime, calendar: calendar), body: body)
        }
    }
}
