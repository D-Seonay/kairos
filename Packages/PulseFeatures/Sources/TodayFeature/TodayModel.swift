import CheckInFeature
import Foundation
import Observation
import PulseContent
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// L'état de l'onglet « Aujourd'hui » : salutation, score du jour et ses facteurs, carte de la séance du jour,
/// check-in si les données manquent. Toutes les lectures et écritures passent par le rafraîchisseur du jour.
@MainActor
@Observable
public final class TodayModel {
    public private(set) var greeting: String
    public private(set) var dateText: String
    public private(set) var lastSync: Date?
    public private(set) var score: TodayScore?
    public private(set) var factors: [FactorDisplay] = []
    public private(set) var marker: String?
    public private(set) var session: TodaySession?
    /// La carte de la séance du jour ; en lecture tant que la première actualisation n'a pas lu le programme.
    private(set) var card: SessionCardState = .loading
    /// La carte de charge d'entraînement : cachée tant que l'historique ne couvre pas 28 jours.
    private(set) var load: LoadCardContent = .hidden
    /// La semaine de décharge à proposer : l'ACWR est resté ≥ 1,5 deux jours de suite (spec M6 §10).
    private(set) var deloadOffer: DeloadOffer?
    /// Les tuiles de tendance sur 14 jours : variabilité, FC repos, sommeil. Vides avant la première lecture.
    private(set) var trends: [TrendTile] = []
    /// La feuille ouverte depuis la carte de la séance : les 20 min de mobilité.
    public var sheet: TodaySheet?
    /// L'écran « Pourquoi » du score du jour ; nul tant qu'il n'y a pas de score du jour.
    private(set) var why: WhyContent?
    /// Vrai quand l'écran « Pourquoi » est poussé dans la pile de l'accueil.
    var isShowingWhy = false
    /// Vrai quand l'écran Nuit est poussé depuis la tuile Sommeil.
    var isShowingNight = false
    /// Change à chaque demande de l'écran Nuit (un rappel de coucher touché) : la vue l'ouvre s'il a une nuit à montrer.
    private(set) var nightRequests = 0

    /// Vrai quand une nuit du cache (60 jours, `NightHistory.historyDays`) a du sommeil : l'écran Nuit a de quoi s'ouvrir.
    private(set) var hasNightInCache = false

    /// La tuile Sommeil ouvre l'écran Nuit dès qu'une nuit du cache a du sommeil, comme l'écran Nuit qui parcourt tout le
    /// cache, même si aucune ne tombe dans les 14 jours de la tuile ; sans nuit, elle reste non touchable (spec sommeil §6.4).
    var canOpenNight: Bool { hasNightInCache }
    public private(set) var isLoading = false
    /// Vrai quand la dernière lecture n'a pas pu calculer le score : sans score affiché, la carte le dit et propose de réessayer.
    public private(set) var scoreFailed = false
    public internal(set) var errorMessage: String?
    /// L'échec de l'enregistrement du choix de décharge, montré sur la carte de la proposition.
    public internal(set) var deloadErrorMessage: String?
    /// Faux tant que l'accès à Apple Santé n'a jamais été demandé sur cet appareil : la bannière du check-in offre alors
    /// « Connecter Apple Santé » au lieu de parler de montre. Vrai sans service d'accès.
    var healthAccessRequested = true
    /// Vrai pendant la demande d'accès : le bouton de la bannière reste inactif.
    var isConnectingHealth = false
    /// L'échec de la demande d'accès, montré sur la bannière.
    var healthAccessError: String?
    public let checkIn = CheckInForm()
    /// Vrai pendant l'enregistrement du check-in : son bouton reste inactif.
    public private(set) var isSubmittingCheckIn = false

    @ObservationIgnored let environment: TodayEnvironment
    /// Le contenu et les exercices de l'utilisateur, relus à chaque actualisation pour nommer et compter les muscles des séances.
    @ObservationIgnored private var directory: ExerciseDirectory
    /// Change à chaque écriture du score (check-in, choix de la séance). Le rafraîchisseur sérialisant ses opérations, la garde
    /// ne peut plus écarter une lecture périmée : elle ne sert qu'en défense, et peut au pire écarter sans dommage un résultat
    /// plus récent que le score écrit.
    @ObservationIgnored private var scoreEpoch = 0
    /// Le check-in du jour, qui sert à lire un score estimé : relu avec le jour, ou les réponses que l'accueil vient d'enregistrer.
    @ObservationIgnored private var todayCheckIn: CheckIn?
    /// Le jour de la dernière actualisation : un jour de plus et le formulaire du check-in repart de zéro.
    @ObservationIgnored private var lastRefreshDay: Date?
    /// Le profil de la dernière actualisation : il règle la hausse de charge et le lancement de la séance.
    @ObservationIgnored private(set) var profile: UserProfile?
    /// La séance en cours, le bilan du jour et l'historique des exercices, relus à chaque actualisation.
    @ObservationIgnored private var live = LiveReading()

    public init(environment: TodayEnvironment) {
        self.environment = environment
        directory = ExerciseDirectory(library: environment.library, userExercises: [])
        greeting = Self.greeting(firstName: nil)
        dateText = Self.dateText(environment.now(), calendar: environment.calendar)
    }

    /// Demande l'écran Nuit : un rappel de coucher touché. La vue le pousse seulement quand une nuit du cache a de quoi
    /// l'ouvrir ; sinon l'accueil reste affiché.
    public func requestNight() {
        nightRequests += 1
    }

    /// L'heure de la dernière lecture d'Apple Santé réussie, « 08:00 » ; précédée du jour quand ce n'est pas aujourd'hui,
    /// « hier 08:00 », « 30 oct. 08:00 » : une synchro ancienne ne passe pas pour celle du matin.
    public var lastSyncText: String? {
        lastSync.map { date -> String in
            let time = Self.timeText(date, calendar: environment.calendar)
            guard let day = Self.syncDay(date, now: environment.now(), calendar: environment.calendar, spoken: false) else {
                return time
            }
            return "\(day) \(time)"
        }
    }

    /// Relit le profil, le programme actif et Apple Santé, recalcule le score et la séance. Un appel pendant une lecture
    /// est ignoré : l'activation de la scène ne peut pas courir contre une actualisation manuelle.
    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let now = environment.now()
        let epoch = scoreEpoch
        dateText = Self.dateText(now, calendar: environment.calendar)
        resetCheckInOnNewDay(now)

        let day = await environment.refresher.refresh(origin: .foreground)
        healthAccessRequested = await environment.healthAccess?.wasRequested() ?? true
        await refreshDirectory()
        profile = day.profile
        live = await environment.readLive(plannedDay: day.plannedDay, previous: live)
        greeting = Self.greeting(firstName: day.profile?.firstName)
        if let readAt = day.readAt {
            lastSync = readAt
        }
        if epoch == scoreEpoch {
            showScoreAndSession(of: day)
        }
        await updateLoadAndTrends(day: day, now: now)
    }

    /// Enregistre les réponses du check-in. Sans effet hors du cas « check-in à faire », avec des réponses incomplètes
    /// ou pendant un enregistrement déjà en cours.
    public func submitCheckIn() async {
        guard !isSubmittingCheckIn, case .needsCheckIn = score, let answers = checkIn.answers else { return }
        isSubmittingCheckIn = true
        defer { isSubmittingCheckIn = false }
        // Un second échec redit le même message : l'effacer d'abord le fait annoncer de nouveau à VoiceOver.
        errorMessage = nil
        do {
            let estimated = try await environment.refresher.saveCheckIn(answers)
            errorMessage = nil
            checkIn.selection = [:]
            todayCheckIn = CheckIn(day: estimated.day, answers: answers, score: estimated.score,
                                   createdAt: estimated.createdAt, updatedAt: estimated.updatedAt)
            applyWritten(estimated)
        } catch DailyScoreError.alreadyMeasured {
            // Un score mesuré est arrivé entre-temps : il remplace le check-in, l'accueil se relit.
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ton check-in.", bundle: .module)
        }
    }

    /// Garde la séance d'origine (`true`) ou revient à la séance ajustée (`false`). Si le choix est refusé
    /// (plus de score aujourd'hui, écriture impossible), l'accueil se relit pour montrer la séance réellement enregistrée.
    public func chooseOriginalSession(_ chosen: Bool) async {
        do {
            applyWritten(try await environment.refresher.chooseOriginalSession(chosen))
        } catch {
            await refresh()
        }
    }

    // MARK: - Interne

    /// Relit les exercices de l'utilisateur, archivés compris : une séance planifiée peut encore les nommer. Si la lecture échoue,
    /// l'annuaire précédent est gardé.
    private func refreshDirectory() async {
        guard let userExercises = try? await environment.userExercises.all(includeArchived: true) else { return }
        directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
    }

    /// Affiche le score lu par le rafraîchissement et la séance qu'il ajuste.
    private func showScoreAndSession(of day: DayRefresh) {
        scoreFailed = day.score == nil
        if let updated = day.score {
            apply(updated)
            todayCheckIn = day.checkIn
            show(day.session)
        } else {
            // Le calcul a échoué : le score affiché reste, la séance suit le programme relu.
            show(TodaySession(plannedDay: day.plannedDay, recovery: scoredToday, deload: session?.isDeload == true))
        }
    }

    /// Les nuits lues font les tendances ; les séances des 28 derniers jours font le ratio de charge, et celles de la veille la
    /// proposition de décharge. Le début de l'historique est celui des Stats, pour que les deux écrans montrent le même
    /// ratio : il vient de la plus ancienne séance enregistrée, lue sans charger l'historique. Si les séances ne se lisent
    /// pas, la carte garde son dernier contenu.
    private func updateLoadAndTrends(day: DayRefresh, now: Date) async {
        let calendar = environment.calendar
        let today = calendar.startOfDay(for: now)
        trends = TrendTile.make(nights: day.nights, day: today, calendar: calendar)
        hasNightInCache = day.nights.contains { $0.sleep != nil }
        guard let start = calendar.date(byAdding: .day, value: -LoadCalculator.requiredHistoryDays, to: today),
              let loadStart = calendar.date(byAdding: .day, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: 1, to: today),
              let sessions = try? await environment.workouts.sessions(from: start, to: end) else { return }
        // Aucune séance enregistrée donne `nil`, qui n'est pas un échec de lecture.
        let oldest: Date?
        do {
            oldest = try await environment.workouts.oldestRecordedStart()
        } catch {
            return
        }
        let historyStart = TrainingLoad.historyStart(oldestRecorded: oldest, onboardingCompletedAt: day.profile?.onboardingCompletedAt)
        load = LoadCardContent.make(TrainingLoad.acwr(
            sessions: sessions.filter { $0.startedAt >= loadStart }, historyStart: historyStart, now: now, calendar: calendar))
        deloadOffer = Deload.offer(sessions: sessions, historyStart: historyStart, profile: day.profile, now: now,
                                   calendar: calendar)
    }

    /// Affiche un score que l'accueil vient d'écrire, et la séance qu'il ajuste.
    func applyWritten(_ recovery: DailyRecovery) {
        scoreEpoch += 1
        scoreFailed = false
        apply(.scored(recovery))
        show(TodaySession(plannedDay: session?.plannedDay ?? .noProgram, recovery: recovery, deload: session?.isDeload == true))
    }

    var scoredToday: DailyRecovery? {
        if case .scored(let recovery) = score { recovery } else { nil }
    }

    private func show(_ session: TodaySession) {
        self.session = session
        card = SessionCardState.make(session: session, score: score, directory: directory, done: live.done,
                                     runDone: live.runDone, inProgressTitle: live.inProgressTitle,
                                     programID: profile?.activeProgramID)
        updateWhy()
    }

    /// L'écran « Pourquoi » suit le score du jour et la séance qu'il ajuste ; sans score, il disparaît et se referme.
    private func updateWhy() {
        guard let recovery = scoredToday, let session else {
            why = nil
            isShowingWhy = false
            return
        }
        let loads = LoadPreview.adjustments(session: session, recovery: recovery, profile: profile, reading: live,
                                            directory: directory, now: environment.now(), calendar: environment.calendar)
        why = WhyContent.make(recovery: recovery, session: session, checkIn: recovery.isEstimated ? todayCheckIn : nil,
                               directory: directory, loadAdjustments: loads, progress: whyProgress,
                               sleepGoalMinutes: SleepGoal.minutes(of: profile))
    }

    /// La séance de la carte vue par l'écran « Pourquoi ».
    private var whyProgress: WhyContent.Progress {
        switch card {
        case .inProgress: .inProgress
        case .done: .done
        default: .toStart
        }
    }

    private func resetCheckInOnNewDay(_ now: Date) {
        let day = environment.calendar.startOfDay(for: now)
        if let lastRefreshDay, lastRefreshDay != day {
            checkIn.selection = [:]
        }
        lastRefreshDay = day
    }

    private func apply(_ updated: TodayScore) {
        score = updated
        if case .scored(let recovery) = updated {
            factors = FactorFormatter.displays(for: recovery)
            marker = FactorFormatter.marker(for: recovery)
        } else {
            factors = []
            marker = nil
        }
    }

    private static func greeting(firstName: String?) -> String {
        let name = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return String(localized: "Bonjour", bundle: .module) }
        return String(localized: "Bonjour \(name)", bundle: .module)
    }

    /// « lundi 2 novembre », dans le fuseau du calendrier injecté.
    private static func dateText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }

    private static func timeText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
