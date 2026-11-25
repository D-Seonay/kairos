import Foundation
import PulseDomain

/// Le coucher conseillé : l'heure de réveil visée, moins l'objectif de sommeil, moins 15 minutes pour s'endormir. Pur : les heures
/// viennent du calendrier donné. Les réveils habituels viennent d'Apple Santé et ne sont jamais écrits dans le profil.
public struct SleepPlan: Sendable, Equatable {
    public static let fallAsleepMinutes = 15
    public static let defaultLeadMinutes = 30
    /// Un rappel se range entre 18:00 le soir même et 03:00 le lendemain, bornes comprises.
    public static let earliestReminderHour = 18
    public static let latestReminderHour = 3
    private static let dayMinutes = 24 * 60

    public let goalMinutes: Int
    public let leadMinutes: Int
    public let reminderEnabled: Bool
    public let chosenWeekdayWake: Int?
    public let chosenWeekendWake: Int?
    public let habitualWeekdayWake: Int?
    public let habitualWeekendWake: Int?

    public init(profile: UserProfile?, wokeUp: [Date], calendar: Calendar) {
        goalMinutes = SleepGoal.minutes(of: profile)
        leadMinutes = profile?.bedtimeReminderLeadMinutes ?? Self.defaultLeadMinutes
        reminderEnabled = profile?.bedtimeReminderEnabled ?? false
        chosenWeekdayWake = profile?.weekdayWakeMinutes
        chosenWeekendWake = profile?.weekendWakeMinutes
        habitualWeekdayWake = HabitualWake.minutes(wokeUp: wokeUp, weekend: false, calendar: calendar)
        habitualWeekendWake = HabitualWake.minutes(wokeUp: wokeUp, weekend: true, calendar: calendar)
    }

    /// L'heure de réveil visée, en minutes après minuit : celle du profil, sinon l'habituelle.
    public func wakeMinutes(weekend: Bool) -> Int? {
        weekend ? (chosenWeekendWake ?? habitualWeekendWake) : (chosenWeekdayWake ?? habitualWeekdayWake)
    }

    /// Le coucher conseillé, en minutes après minuit (0…1439), peut-être après minuit pour un réveil tôt.
    public func bedtimeMinutes(weekend: Bool) -> Int? {
        guard let wake = wakeMinutes(weekend: weekend) else { return nil }
        let minutes = wake - goalMinutes - Self.fallAsleepMinutes
        return (minutes % Self.dayMinutes + Self.dayMinutes) % Self.dayMinutes
    }

    /// Vrai quand le lendemain du soir donné est un samedi ou un dimanche.
    public static func wakesOnWeekend(afterEvening day: Date, calendar: Calendar) -> Bool {
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        let weekday = Weekday(date: next, calendar: calendar)
        return weekday == .saturday || weekday == .sunday
    }

    /// Le coucher de la nuit qui suit le soir donné : le réveil du lendemain, moins l'objectif et le temps d'endormissement.
    /// Le réveil se construit à l'heure locale, puis on retire des minutes : un soir de changement d'heure garde le bon réveil.
    public func bedtime(onEvening day: Date, calendar: Calendar) -> Date? {
        guard let wake = wakeMinutes(weekend: Self.wakesOnWeekend(afterEvening: day, calendar: calendar)),
              let next = calendar.date(byAdding: .day, value: 1, to: day),
              let wakeDate = calendar.date(bySettingHour: wake / 60, minute: wake % 60, second: 0, of: next) else { return nil }
        return calendar.date(byAdding: .minute, value: -(goalMinutes + Self.fallAsleepMinutes), to: wakeDate)
    }

    /// Le rappel : `leadMinutes` avant le coucher ; `nil` hors de 18:00 le soir même … 03:00 le lendemain, bornes comprises.
    public func reminderDate(onEvening day: Date, calendar: Calendar) -> Date? {
        guard let bedtime = bedtime(onEvening: day, calendar: calendar),
              let reminder = calendar.date(byAdding: .minute, value: -leadMinutes, to: bedtime),
              let next = calendar.date(byAdding: .day, value: 1, to: day),
              let earliest = calendar.date(bySettingHour: Self.earliestReminderHour, minute: 0, second: 0, of: day),
              let latest = calendar.date(bySettingHour: Self.latestReminderHour, minute: 0, second: 0, of: next),
              reminder >= earliest, reminder <= latest else { return nil }
        return reminder
    }

    /// « 22:45 », « 00:45 », « 07:00 ».
    public static func clockText(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Vrai quand l'un des cinq réglages du sommeil diffère : l'objectif, les deux réveils, le rappel et son avance.
    public static func settingsChanged(from old: UserProfile, to new: UserProfile) -> Bool {
        old.sleepGoalMinutes != new.sleepGoalMinutes
            || old.weekdayWakeMinutes != new.weekdayWakeMinutes
            || old.weekendWakeMinutes != new.weekendWakeMinutes
            || old.bedtimeReminderEnabled != new.bedtimeReminderEnabled
            || old.bedtimeReminderLeadMinutes != new.bedtimeReminderLeadMinutes
    }
}
