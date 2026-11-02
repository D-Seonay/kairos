import Foundation
import Observation
import PulseDomain
import PulseRecoveryEngine
import PulseServices

/// Une routine du programme actif, telle que la liste « Mes routines » la résume.
public struct RoutineSummary: Sendable, Equatable, Identifiable {
    public var day: RoutineDay
    public var exerciseCount: Int
    /// La durée estimée d'une séance de musculation ; l'objectif de durée d'une course (0 sans objectif de durée).
    public var estimatedMinutes: Int
    /// Les jours de la semaine type où la routine tombe, de lundi à dimanche.
    public var weekdays: [Weekday]

    public init(day: RoutineDay, exerciseCount: Int, estimatedMinutes: Int, weekdays: [Weekday]) {
        self.day = day
        self.exerciseCount = exerciseCount
        self.estimatedMinutes = estimatedMinutes
        self.weekdays = weekdays
    }

    public var id: UUID { day.id }
}

/// L'état de l'onglet « Séance » : la séance du jour, la prochaine course et les routines du programme actif.
/// Le score du jour est relu tel qu'enregistré, sans relire Apple Santé : l'accueil s'en charge.
@MainActor
@Observable
public final class TrainModel {
    public private(set) var today: TodaySession?
    public private(set) var program: Program?
    public private(set) var routines: [RoutineSummary] = []
    /// La course du jour, ou la prochaine de la semaine type.
    public private(set) var nextRun: NextSession?
    public private(set) var directory: ExerciseDirectory
    public private(set) var errorMessage: String?
    /// Le titre de la séance en cours, relu à chaque `refresh()` ; `nil` sans séance en cours.
    public private(set) var activeSessionTitle: String?
    /// Le début de la séance en cours, pour dire depuis combien de temps elle dure.
    public private(set) var activeSessionStartedAt: Date?
    /// Le jour de la semaine de la dernière lecture, pour dire « aujourd'hui » ou « demain » de la prochaine course.
    private(set) var weekday: Weekday?

    @ObservationIgnored private let environment: TrainEnvironment
    /// Le profil et le score du jour de la dernière lecture : ils règlent ce qu'une séance lancée applique.
    @ObservationIgnored private var profile: UserProfile?
    @ObservationIgnored private var scoredToday: DailyRecovery?
    @ObservationIgnored private var isRefreshing = false

    public init(environment: TrainEnvironment) {
        self.environment = environment
        directory = ExerciseDirectory(library: environment.library, userExercises: [])
    }

    /// Relit le profil, le programme actif, le score du jour et les exercices de l'utilisateur. Un appel pendant une lecture
    /// est ignoré ; si une lecture échoue, l'écran garde son dernier état et affiche une erreur.
    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let now = environment.now()
        await refreshDirectory()
        let active = await environment.activeSession.current()
        activeSessionTitle = active?.title
        activeSessionStartedAt = active?.startedAt
        do {
            let profile = try await environment.profiles.load()
            let program = try await activeProgram(of: profile)
            let recovery = try await todaysRecovery(now: now)
            let planned = TodayPlanner.plan(program: program, on: now, calendar: environment.calendar)
            self.profile = profile
            scoredToday = recovery
            self.program = program
            weekday = Weekday(date: now, calendar: environment.calendar)
            today = TodaySession(plannedDay: planned, recovery: recovery)
            routines = program.map(summaries(of:)) ?? []
            nextRun = program.flatMap { nextRun(in: $0, now: now) }
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire ton programme.", bundle: .module)
        }
    }

    /// Le modèle de la bibliothèque d'exercices, sur le même environnement que l'onglet.
    public func libraryModel(mode: LibraryMode) -> LibraryModel {
        LibraryModel(environment: environment, mode: mode)
    }

    /// Le modèle de l'éditeur de programme, sur le même environnement que l'onglet.
    public func programEditorModel() -> ProgramEditorModel {
        ProgramEditorModel(environment: environment)
    }

    /// Le modèle de l'éditeur de la routine `dayID` du programme `programID`.
    public func routineEditorModel(programID: UUID, dayID: UUID) -> RoutineEditorModel {
        RoutineEditorModel(environment: environment, programID: programID, dayID: dayID)
    }

    /// Le modèle de l'historique des séances, sur le même environnement que l'onglet.
    public func historyModel() -> HistoryModel {
        HistoryModel(environment: environment)
    }

    /// Le modèle du parcours d'import de l'historique Hevy.
    public func hevyImportModel() -> HevyImportModel {
        HevyImportModel(environment: environment)
    }

    /// Le modèle du détail de la séance `sessionID`.
    public func sessionDetailModel(sessionID: UUID) -> SessionDetailModel {
        SessionDetailModel(environment: environment, sessionID: sessionID)
    }

    /// Ajoute une routine vide au programme actif, relit l'onglet et rend l'identifiant de la routine.
    public func addRoutine(named name: String) async throws -> UUID {
        let editor = programEditorModel()
        await editor.load()
        let id = try await editor.addRoutine(named: name)
        await refresh()
        return id
    }

    /// La routine `dayID` du programme actif avec les ajustements du jour (le score du jour et « Séance d'origine » s'il a été
    /// choisie). `nil` pour un jour inconnu ou une course : les courses ne se démarrent pas avant M6.
    public func launch(routine dayID: UUID) -> SessionLaunch? {
        guard let day = program?.days.first(where: { $0.id == dayID }), day.kind == .strength else { return nil }
        return SessionLaunch.routine(day, programID: program?.id, recovery: scoredToday,
                                     originalChosen: scoredToday?.originalSessionChosen == true, profile: profile)
    }

    /// La séance de musculation du jour, ajustée ou d'origine ; `nil` un jour de repos, de course ou sans programme.
    public func launchToday() -> SessionLaunch? {
        guard case .strength(let day) = today?.plannedDay else { return nil }
        return launch(routine: day.id)
    }

    /// Une séance sans routine, sous la règle de hausse du jour.
    public func freeLaunch() -> SessionLaunch {
        let policy = ProgressionPolicy.make(recovery: scoredToday, adaptationEnabled: profile?.adaptationEnabled ?? true,
                                            startsOriginalAfterOverreach: scoredToday?.category == .overreached)
        return SessionLaunch.free(policy: policy)
    }

    // MARK: - Interne

    /// Les exercices de l'utilisateur, archivés compris : une routine peut encore les nommer. Si la lecture échoue,
    /// l'annuaire précédent est gardé.
    private func refreshDirectory() async {
        guard let userExercises = try? await environment.userExercises.all(includeArchived: true) else { return }
        directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
    }

    private func activeProgram(of profile: UserProfile?) async throws -> Program? {
        guard let id = profile?.activeProgramID else { return nil }
        return try await environment.programs.program(id: id)
    }

    /// Le score enregistré pour le jour de `now` ; aucun avant 4 h, l'accueil ne l'ayant pas encore calculé.
    private func todaysRecovery(now: Date) async throws -> DailyRecovery? {
        let calendar = environment.calendar
        let day = calendar.startOfDay(for: now)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return try await environment.recovery.dailyRecoveries(from: day, to: next).first
    }

    /// Les jours du programme dans leur ordre, avec les jours de la semaine type où ils tombent.
    private func summaries(of program: Program) -> [RoutineSummary] {
        program.days.sorted { $0.order < $1.order }.map { day in
            let minutes = day.kind == .run
                ? day.runTargetMinutes ?? 0
                : SessionSummary.make(day: day, directory: directory).estimatedMinutes
            return RoutineSummary(day: day, exerciseCount: day.exercises.count, estimatedMinutes: minutes,
                                  weekdays: weekdays(of: day, in: program))
        }
    }

    private func weekdays(of day: RoutineDay, in program: Program) -> [Weekday] {
        Weekday.allCases.filter { weekday in
            program.weekLayout.indices.contains(weekday.index) && program.weekLayout[weekday.index] == day.id
        }
    }

    /// La course du jour, sinon la première de la semaine type après aujourd'hui (en bouclant sur la semaine).
    private func nextRun(in program: Program, now: Date) -> NextSession? {
        let today = Weekday(date: now, calendar: environment.calendar)
        for offset in 0..<Weekday.allCases.count {
            let weekday = Weekday.allCases[(today.index + offset) % Weekday.allCases.count]
            guard program.weekLayout.indices.contains(weekday.index), let id = program.weekLayout[weekday.index],
                  let day = program.days.first(where: { $0.id == id }), day.kind == .run else { continue }
            return NextSession(day: day, weekday: weekday)
        }
        return nil
    }
}
