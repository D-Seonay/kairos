import Foundation
import PulseDomain

/// Le seul passage qui lit Apple Santé, met le score du jour à jour, décrit la séance, publie l'instantané du widget et,
/// en arrière-plan, envoie la notification du matin. L'écran d'accueil (premier plan) et la livraison Apple Santé
/// (arrière-plan) l'appellent tous deux : ses opérations passent l'une après l'autre par la même file,
/// pour que deux livraisons rapprochées n'annoncent pas deux fois le même score.
public final class DayRefresher: Sendable {
    public enum Origin: Sendable {
        case foreground, background
    }

    private let profiles: any ProfileRepository
    private let programs: any ProgramRepository
    private let recovery: any RecoveryRepository
    private let nightHistory: NightHistory
    private let scores: DailyScoreService
    private let widgets: any WidgetPublishing
    private let notifications: any NotificationScheduling
    private let activity: any DayActivityLog
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, recovery: any RecoveryRepository,
                nightHistory: NightHistory, scores: DailyScoreService, widgets: any WidgetPublishing,
                notifications: any NotificationScheduling, activity: any DayActivityLog, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.recovery = recovery
        self.nightHistory = nightHistory
        self.scores = scores
        self.widgets = widgets
        self.notifications = notifications
        self.activity = activity
        self.calendar = calendar
        self.now = now
    }

    /// Lit Apple Santé, met le score à jour et publie l'instantané. Au premier plan, note l'ouverture de l'app et retire la
    /// notification du matin ; en arrière-plan, annonce le score une seule fois par jour, et ne fait rien tant que
    /// l'onboarding n'est pas terminé.
    public func refresh(origin: Origin) async -> DayRefresh {
        // La file ne lève que ce que lève l'opération, et celle-ci ne lève pas.
        let result = try? await queue.run { await self.pass(origin) }
        return result ?? .empty(profile: nil)
    }

    /// Enregistre le check-in du jour et republie l'instantané, estimé.
    public func saveCheckIn(_ answers: CheckInAnswers) async throws -> DailyRecovery {
        try await queue.run {
            let now = self.now()
            let plannedDay = await self.currentPlannedDay(now: now)
            let saved = try await self.scores.saveCheckIn(answers, plannedDay: plannedDay, now: now)
            await self.publish(saved, plannedDay: plannedDay)
            return saved
        }
    }

    /// Enregistre le choix « Séance d'origine » et republie l'instantané, allégé ou non.
    public func chooseOriginalSession(_ chosen: Bool) async throws -> DailyRecovery {
        try await queue.run {
            let now = self.now()
            let plannedDay = await self.currentPlannedDay(now: now)
            let saved = try await self.scores.chooseOriginalSession(chosen, now: now)
            await self.publish(saved, plannedDay: plannedDay)
            return saved
        }
    }

    // MARK: - Interne

    private func pass(_ origin: Origin) async -> DayRefresh {
        let now = now()
        let profile = try? await profiles.load()
        if origin == .background, profile?.onboardingCompletedAt == nil {
            return .empty(profile: profile)
        }
        if origin == .foreground {
            activity.markOpened(at: now)
            await notifications.cancelMorningScore()
        }
        let plannedDay = await plannedDay(for: profile, now: now)
        let history = await nightHistory.refresh(now: now)
        let score = try? await scores.update(nights: history.nights, plannedDay: plannedDay, now: now)
        let scored: DailyRecovery? = if case .scored(let recovery)? = score { recovery } else { nil }
        let session = TodaySession(plannedDay: plannedDay, recovery: scored)
        if let scored {
            await widgets.publish(WidgetSnapshot(recovery: scored, session: session))
            if origin == .background, let profile {
                await notifyIfDue(scored, session: session, profile: profile, now: now)
            }
        }
        return DayRefresh(profile: profile, nights: history.nights, readAt: history.readAt, plannedDay: plannedDay, score: score,
                          session: session, checkIn: await checkIn(of: scored, now: now))
    }

    /// Annonce le score du matin si la règle le permet, puis retient le jour pour que la livraison suivante se taise.
    private func notifyIfDue(_ scored: DailyRecovery, session: TodaySession, profile: UserProfile, now: Date) async {
        guard let message = MorningNotificationRule.message(
            recovery: scored, session: session, profile: profile, lastOpenedAt: activity.lastOpenedAt(),
            lastNotifiedDay: activity.lastNotifiedDay(), now: now, calendar: calendar) else { return }
        await notifications.scheduleMorningScore(message)
        activity.markNotified(day: scored.day)
    }

    private func publish(_ scored: DailyRecovery, plannedDay: PlannedDay) async {
        let session = TodaySession(plannedDay: plannedDay, recovery: scored)
        await widgets.publish(WidgetSnapshot(recovery: scored, session: session))
    }

    /// Ce que le programme actif du profil enregistré prévoit à `now`.
    private func currentPlannedDay(now: Date) async -> PlannedDay {
        await plannedDay(for: try? await profiles.load(), now: now)
    }

    private func plannedDay(for profile: UserProfile?, now: Date) async -> PlannedDay {
        var program: Program?
        if let id = profile?.activeProgramID {
            program = try? await programs.program(id: id)
        }
        return TodayPlanner.plan(program: program, on: now, calendar: calendar)
    }

    /// Le check-in du jour, quand le score en est estimé.
    private func checkIn(of scored: DailyRecovery?, now: Date) async -> CheckIn? {
        guard let scored, scored.isEstimated else { return nil }
        let day = calendar.startOfDay(for: now)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return (try? await recovery.checkIns(from: day, to: next))?.first
    }
}
