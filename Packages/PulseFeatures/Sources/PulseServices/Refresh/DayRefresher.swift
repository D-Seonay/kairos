import Foundation
import PulseDomain
import Synchronization

/// Le seul passage qui lit Apple Santé, met le score du jour à jour, décrit la séance, publie l'instantané du widget et,
/// en arrière-plan, envoie la notification du matin. L'écran d'accueil (premier plan) et la livraison Apple Santé
/// (arrière-plan) l'appellent tous deux : ses opérations passent l'une après l'autre par la même file,
/// pour que deux livraisons rapprochées n'annoncent pas deux fois le même score. Les écritures du Planning y passent aussi.
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
    /// La semaine datée : ses déplacements changent la séance du jour (spec M6 §4).
    private let scheduledDays: (any ScheduledDayRepository)?
    /// Les courses et les vélos d'Apple Santé, lus après les nuits (spec M6 §3).
    private let workoutHistory: WorkoutHistory?
    /// Le poids et la masse grasse d'Apple Santé, lus juste après les entraînements (spec M7 §14).
    private let bodyHistory: BodyHistory?
    /// Les règles anti-interférence, appliquées après la lecture des entraînements (spec M6 §9).
    private let antiInterference: AntiInterferenceService?
    /// La série, la semaine et la charge publiées avec l'instantané du widget (spec M6 §11).
    private let planning: PlanningService?
    /// Le déplacement des valeurs Apple Santé laissées dans le magasin synchronisé, avant toute lecture (spec M8 §5.2).
    private let relocation: (any HealthDataRelocating)?
    /// Les meilleurs segments des courses Pulse, calculés une fois par course pour les records (5 km, 10 km, semi).
    private let runBestEfforts: RunBestEffortIndex?
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    /// La file des opérations du passage. C'est celle des écritures de `planning` quand il est fourni : un déplacement ou un
    /// refus dans le Planning attend la fin du passage en cours, et le passage suivant attend la fin du déplacement.
    private let queue: SerialTaskQueue
    /// Vrai après une suppression totale, tant qu'aucun profil n'a terminé l'onboarding : une passe ne relit alors ni Apple
    /// Santé ni ne republie le widget (spec M4 §20).
    private let erased = Mutex(false)

    /// Ce que le programme prévoit : `display` sert à l'écran, `forScore` au score du jour, `nil` quand le profil ou le programme
    /// n'a pas pu être lu, pour que le score garde les ajustements déjà enregistrés.
    private struct DayPlan {
        var display: PlannedDay
        var forScore: PlannedDay?
        /// Vrai pendant une semaine de décharge acceptée (spec M6 §10).
        var deload = false
    }

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, recovery: any RecoveryRepository,
                nightHistory: NightHistory, scores: DailyScoreService, widgets: any WidgetPublishing,
                notifications: any NotificationScheduling, activity: any DayActivityLog,
                scheduledDays: (any ScheduledDayRepository)? = nil, workoutHistory: WorkoutHistory? = nil,
                bodyHistory: BodyHistory? = nil, antiInterference: AntiInterferenceService? = nil,
                planning: PlanningService? = nil, relocation: (any HealthDataRelocating)? = nil,
                runBestEfforts: RunBestEffortIndex? = nil, calendar: Calendar, now: @escaping @Sendable () -> Date) {
        self.profiles = profiles
        self.programs = programs
        self.recovery = recovery
        self.nightHistory = nightHistory
        self.scores = scores
        self.widgets = widgets
        self.notifications = notifications
        self.activity = activity
        self.scheduledDays = scheduledDays
        self.workoutHistory = workoutHistory
        self.bodyHistory = bodyHistory
        self.antiInterference = antiInterference
        self.planning = planning
        self.queue = planning?.writes ?? SerialTaskQueue()
        self.relocation = relocation
        self.runBestEfforts = runBestEfforts
        self.calendar = calendar
        self.now = now
    }

    /// Lit Apple Santé, met le score à jour et publie l'instantané. Au premier plan, note l'ouverture de l'app et retire la
    /// notification du matin ; en arrière-plan, annonce le score une seule fois par jour. Ne fait rien tant que l'onboarding
    /// n'est pas terminé ; au premier plan, il en va de même juste après une suppression totale, jusqu'à la fin du nouvel
    /// onboarding.
    public func refresh(origin: Origin) async -> DayRefresh {
        // La file ne lève que ce que lève l'opération, et celle-ci ne lève pas.
        let result = try? await queue.run { await self.pass(origin) }
        return result ?? .empty(profile: nil)
    }

    /// Enregistre le check-in du jour et republie l'instantané, estimé.
    public func saveCheckIn(_ answers: CheckInAnswers) async throws -> DailyRecovery {
        try await queue.run {
            let now = self.now()
            let plan = await self.currentPlan(now: now)
            let saved = try await self.scores.saveCheckIn(answers, plannedDay: plan.forScore, now: now)
            await self.publish(saved, plan: plan)
            return saved
        }
    }

    /// Enregistre le choix « Séance d'origine » et republie l'instantané, allégé ou non.
    public func chooseOriginalSession(_ chosen: Bool) async throws -> DailyRecovery {
        try await queue.run {
            let now = self.now()
            let plan = await self.currentPlan(now: now)
            let saved = try await self.scores.chooseOriginalSession(chosen, now: now)
            await self.publish(saved, plan: plan)
            return saved
        }
    }

    /// Accepte (`true`) ou refuse la semaine de décharge proposée (spec M6 §10) ; la décision vaut jusqu'au dimanche suivant.
    public func decideDeload(_ accepted: Bool) async throws {
        try await queue.run {
            let now = self.now()
            try await self.profiles.update { profile in
                if accepted {
                    profile.deloadWeekStartedAt = now
                } else {
                    profile.deloadDeclinedAt = now
                }
                profile.updatedAt = now
            }
        }
    }

    /// Efface tout avec `eraser`, dans la file : après le passage en cours, et avant le suivant.
    public func eraseEverything(using eraser: any DataEraser, options: EraseOptions) async throws {
        try await queue.run {
            try await eraser.eraseEverything(options: options)
            self.erased.withLock { $0 = true }
        }
    }

    // MARK: - Interne

    private func pass(_ origin: Origin) async -> DayRefresh {
        let now = now()
        let (profile, profileReadFailed) = await loadProfile()
        let onboarded = profile?.onboardingCompletedAt != nil
        let erasedSinceOnboarding = erased.withLock { flag in
            if onboarded { flag = false }
            return flag
        }
        if !onboarded, origin == .background || (erasedSinceOnboarding && !profileReadFailed) {
            return .empty(profile: profile)
        }
        if origin == .foreground {
            activity.markOpened(at: now)
            await notifications.cancelMorningScore()
        }
        // iCloud peut redescendre d'anciennes lignes à tout moment : on les déplace avant de lire. Un échec ne retient pas le passage.
        _ = try? await relocation?.relocate()
        let history = await nightHistory.refresh(now: now)
        // Les nuits enregistrées avant les phases les reçoivent si leur total n'a pas bougé ; un échec ne retient pas le passage.
        try? await recovery.backfillSleepStages(history.nights)
        await workoutHistory?.refresh(now: now)
        await bodyHistory?.refresh(now: now)
        // Les records de course lisent ce cache : un tracé arrivé d'iCloud ou une course d'avant le cache y entre ici.
        await runBestEfforts?.refresh(now: now)
        // Une semaine illisible reste telle quelle : la séance du jour suit les lignes déjà écrites.
        try? await antiInterference?.apply(nights: history.nights)
        let plan = await plan(for: profile, readFailed: profileReadFailed, now: now)
        let plannedDay = plan.display
        let score = try? await scores.update(nights: history.nights, plannedDay: plan.forScore, now: now)
        let scored: DailyRecovery? = if case .scored(let recovery)? = score { recovery } else { nil }
        let session = TodaySession(plannedDay: plannedDay, recovery: scored, deload: plan.deload)
        // L'ambiance des widgets suit le profil lu, même sans score ; un profil illisible laisse celle déjà partagée.
        if let profile { await widgets.publishTheme(profile.theme) }
        if let scored {
            await widgets.publish(await snapshot(scored, session: session, profile: profile))
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

    private func publish(_ scored: DailyRecovery, plan: DayPlan) async {
        let session = TodaySession(plannedDay: plan.display, recovery: scored, deload: plan.deload)
        await widgets.publish(await snapshot(scored, session: session, profile: await loadProfile().profile))
    }

    /// L'instantané du jour, avec la série, la semaine et la charge quand elles se lisent, et la silhouette du profil
    /// (celle de femme sans profil lisible).
    private func snapshot(_ scored: DailyRecovery, session: TodaySession, profile: UserProfile?) async -> WidgetSnapshot {
        var snapshot = WidgetSnapshot(recovery: scored, session: session).adding(try? await planning?.widgetPlanning())
        snapshot.muscleMapFigure = MuscleMapFigure(sex: profile?.sex ?? .unspecified)
        return snapshot
    }

    /// Le profil enregistré, et si sa lecture a échoué : un profil absent n'est pas un profil illisible.
    private func loadProfile() async -> (profile: UserProfile?, readFailed: Bool) {
        do {
            return (try await profiles.load(), false)
        } catch {
            return (nil, true)
        }
    }

    /// Ce que le programme actif du profil enregistré prévoit à `now`.
    private func currentPlan(now: Date) async -> DayPlan {
        let (profile, readFailed) = await loadProfile()
        return await plan(for: profile, readFailed: readFailed, now: now)
    }

    private func plan(for profile: UserProfile?, readFailed: Bool, now: Date) async -> DayPlan {
        guard !readFailed else { return DayPlan(display: .noProgram, forScore: nil) }
        var program: Program?
        if let id = profile?.activeProgramID {
            do {
                program = try await programs.program(id: id)
            } catch {
                return DayPlan(display: .noProgram, forScore: nil)
            }
        }
        let planned = TodayPlanner.plan(program: program, on: now, calendar: calendar, overrides: await overrides(now: now))
        let deload = Deload.status(profile: profile, now: now, calendar: calendar).isActive
        return DayPlan(display: planned, forScore: planned, deload: deload)
    }

    /// Les lignes de la semaine datée d'aujourd'hui et des 7 jours suivants ; aucune si leur lecture échoue.
    private func overrides(now: Date) async -> [ScheduledDay] {
        let today = calendar.startOfDay(for: now)
        guard let scheduledDays, let end = calendar.date(byAdding: .day, value: 8, to: today) else { return [] }
        return (try? await scheduledDays.days(from: today, to: end)) ?? []
    }

    /// Le check-in du jour, quand le score en est estimé.
    private func checkIn(of scored: DailyRecovery?, now: Date) async -> CheckIn? {
        guard let scored, scored.isEstimated else { return nil }
        let day = calendar.startOfDay(for: now)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return (try? await recovery.checkIns(from: day, to: next))?.first
    }
}
