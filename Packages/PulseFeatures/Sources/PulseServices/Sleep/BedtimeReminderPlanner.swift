import Foundation
import PulseDomain

/// Les rappels de coucher à planifier : un par soir, de la veille à J+6, jamais dans le passé ni hors de 18:00 … 03:00. Le soir de
/// la veille ne reste qu'entre minuit et 03:00, tant que son rappel n'a pas sonné : une planification à 00:05 garde le rappel de
/// 00:15. Pur : les heures viennent du calendrier donné.
public enum BedtimeReminderPlanner {
    public static let horizonEvenings = 7

    /// `sessionName(jour)` : le nom de la séance prévue ce jour-là, `nil` un jour de repos. `nightAsleepMinutes(jour)` : les
    /// minutes endormies de la nuit qui finit ce matin-là (minuit local du jour de réveil), `nil` si elle est inconnue ; un soir ne
    /// parle de nuit courte que de celle qui a fini le matin même. `sleepDebtMinutes(jour)` : la dette des 7 nuits qui finissent ce
    /// matin-là (`SleepDebtWindow`), `nil` si la nuit du matin est inconnue. Le rappel parle de la dette à partir d'une heure, et
    /// seulement quand les nuits d'avant y ajoutent : une dette qui ne vient que de la nuit d'hier se dit mieux « nuit courte ».
    public static func reminders(plan: SleepPlan, nightAsleepMinutes: (Date) -> Int?, sleepDebtMinutes: (Date) -> Int? = { _ in nil },
                                 sessionName: (Date) -> String?, now: Date, calendar: Calendar) -> [BedtimeReminder] {
        guard plan.reminderEnabled else { return [] }
        let today = calendar.startOfDay(for: now)
        return (-1..<horizonEvenings).compactMap { offset -> BedtimeReminder? in
            guard let evening = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = plan.reminderDate(onEvening: evening, calendar: calendar), fire > now,
                  let bedtime = plan.bedtime(onEvening: evening, calendar: calendar),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening),
                  let wake = plan.wakeMinutes(weekend: SleepPlan.wakesOnWeekend(afterEvening: evening, calendar: calendar))
            else { return nil }
            let lastNight = nightAsleepMinutes(evening)
            let shortNight = lastNight.flatMap { SleepGoal.isShortNight(asleepMinutes: $0, goalMinutes: plan.goalMinutes) ? $0 : nil }
            let lastNightGap = max(0, plan.goalMinutes - (lastNight ?? plan.goalMinutes))
            let debt = sleepDebtMinutes(evening).flatMap {
                $0 >= BedtimeReminderText.debtThresholdMinutes && $0 > lastNightGap ? $0 : nil
            }
            let body = BedtimeReminderText.body(goalMinutes: plan.goalMinutes, wakeMinutes: wake, shortNightMinutes: shortNight,
                                                sessionName: sessionName(tomorrow), debtMinutes: debt)
            return BedtimeReminder(evening: evening, fireDate: fire,
                                   title: BedtimeReminderText.title(bedtime: bedtime, calendar: calendar), body: body)
        }
    }
}
