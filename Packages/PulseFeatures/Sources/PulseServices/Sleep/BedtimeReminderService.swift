import Foundation
import PulseContent
import PulseDomain

/// Lit le profil, les nuits du cache d'Apple Santé et le planning, et remet les rappels de coucher au planificateur. Les réveils
/// habituels sont recalculés à chaque fois et ne sont jamais écrits. Les recalculs passent l'un après l'autre : chacun lit le profil
/// et remplace les rappels d'un seul tenant, un rappel désactivé entre-temps n'est pas recouvert par un recalcul plus ancien.
public struct BedtimeReminderService: Sendable {
    private let profiles: any ProfileRepository
    private let programs: any ProgramRepository
    private let scheduledDays: (any ScheduledDayRepository)?
    private let bedtime: HabitualBedtimeReader
    private let reminders: any BedtimeReminderScheduling
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, scheduledDays: (any ScheduledDayRepository)?,
                bedtime: HabitualBedtimeReader, reminders: any BedtimeReminderScheduling, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.scheduledDays = scheduledDays
        self.bedtime = bedtime
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
    }

    /// Recalcule les rappels des sept prochains soirs, et celui de la veille tant qu'il n'a pas sonné. Un profil illisible laisse
    /// les rappels en attente en place ; un rappel désactivé ou sans coucher conseillé les retire (remplacement par une liste vide).
    public func reschedule() async {
        try? await queue.run { await self.replaceReminders() }
    }

    /// Le plan du sommeil d'aujourd'hui ; `nil` si le profil est illisible.
    public func plan() async -> SleepPlan? {
        guard let (profile, nights) = await load(now: now()) else { return nil }
        return SleepPlan(profile: profile, wokeUp: nights.map(\.wokeUp), calendar: calendar)
    }

    // MARK: - Interne

    /// Une course est annoncée par son type (une course rendue facile par la règle des jambes lourdes, en sortie facile), la
    /// musculation par le nom du jour.
    private func replaceReminders() async {
        let now = now()
        guard let (profile, nights) = await load(now: now) else { return }
        let plan = SleepPlan(profile: profile, wokeUp: nights.map(\.wokeUp), calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let routine = plan.reminderEnabled ? await routine(of: profile, today: today) : nil
        let planned = BedtimeReminderPlanner.reminders(
            plan: plan,
            nightAsleepMinutes: { day in nights.first { calendar.isDate($0.day, inSameDayAs: day) }?.asleepMinutes },
            sleepDebtMinutes: { day in
                SleepDebtWindow.minutes(endingAt: day, nights: nights, goalMinutes: plan.goalMinutes, calendar: calendar)
            },
            sessionName: { day in
                routine.flatMap { TodayPlanner.routineDay(of: $0.program, on: day, calendar: calendar, overrides: $0.overrides) }
                    .map { $0.runType?.localizedName ?? $0.name }
            },
            now: now, calendar: calendar)
        await reminders.replaceBedtimeReminders(with: planned)
    }

    /// Le profil (peut-être absent) et les 14 dernières nuits ; `nil` si le profil est illisible.
    private func load(now: Date) async -> (UserProfile?, [NightSleep])? {
        let profile: UserProfile?
        do {
            profile = try await profiles.load()
        } catch {
            return nil
        }
        return (profile, await bedtime.nights(now: now))
    }

    /// Le programme actif et les lignes de la semaine datée d'aujourd'hui à J+8 (les lendemains des soirs planifiés). Un programme ou
    /// des lignes illisibles donnent des rappels sans séance.
    private func routine(of profile: UserProfile?, today: Date) async -> (program: Program, overrides: [ScheduledDay])? {
        guard let id = profile?.activeProgramID, let program = try? await programs.program(id: id) else { return nil }
        guard let scheduledDays else { return (program, []) }
        guard let end = calendar.date(byAdding: .day, value: BedtimeReminderPlanner.horizonEvenings + 1, to: today),
              let overrides = try? await scheduledDays.days(from: today, to: end) else { return nil }
        return (program, overrides)
    }
}
