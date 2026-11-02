import Foundation
import Observation
import PulseDomain
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
    /// Le jour de la semaine de la dernière lecture, pour dire « aujourd'hui » ou « demain » de la prochaine course.
    private(set) var weekday: Weekday?

    @ObservationIgnored private let environment: TrainEnvironment
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
        do {
            let program = try await activeProgram()
            let recovery = try await todaysRecovery(now: now)
            let planned = TodayPlanner.plan(program: program, on: now, calendar: environment.calendar)
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

    // MARK: - Interne

    /// Les exercices de l'utilisateur, archivés compris : une routine peut encore les nommer. Si la lecture échoue,
    /// l'annuaire précédent est gardé.
    private func refreshDirectory() async {
        guard let userExercises = try? await environment.userExercises.all(includeArchived: true) else { return }
        directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
    }

    private func activeProgram() async throws -> Program? {
        guard let id = try await environment.profiles.load()?.activeProgramID else { return nil }
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
