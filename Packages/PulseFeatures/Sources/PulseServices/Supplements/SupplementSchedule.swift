import Foundation
import PulseDomain

/// Un moment de la journée sur l'écran des compléments (spec M5 §4), dans l'ordre d'affichage.
public enum SupplementMoment: Int, Sendable, CaseIterable, Comparable {
    case morning
    case afternoon
    case workout
    case evening

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Un complément dû un jour donné : son moment, son heure prévue, et sa prise du jour s'il est pris.
public struct SupplementDueItem: Sendable, Equatable, Identifiable {
    public var supplement: Supplement
    public var moment: SupplementMoment
    /// Minutes après minuit.
    public var plannedMinutes: Int
    /// La dernière prise du jour ; `nil` tant qu'il n'est pas pris.
    public var intake: SupplementIntake?
    /// Vrai quand l'heure d'un complément « après la séance » vient de la fin réelle de la séance du jour.
    public var isWorkoutFinished: Bool

    public var id: UUID { supplement.id }
    public var isTaken: Bool { intake != nil }

    public init(supplement: Supplement, moment: SupplementMoment, plannedMinutes: Int, intake: SupplementIntake? = nil,
                isWorkoutFinished: Bool = false) {
        self.supplement = supplement
        self.moment = moment
        self.plannedMinutes = plannedMinutes
        self.intake = intake
        self.isWorkoutFinished = isWorkoutFinished
    }
}

/// Ce que l'on sait pour planifier les compléments (spec M5 §4) : les compléments, les prises, les jours d'entraînement du
/// programme actif et les séances récentes. Pur : les heures et les jours viennent du calendrier donné.
public struct SupplementSchedule: Sendable {
    /// Heure habituelle de séance sans historique : 18:00.
    public static let defaultSessionMinutes = 18 * 60
    /// Avance d'un complément « avant la séance ».
    public static let beforeWorkoutLeadMinutes = 30
    /// Durée supposée d'une séance pas encore finie, pour placer « après la séance ».
    public static let assumedSessionMinutes = 60
    static let habitualSampleSize = 10
    static let habitualWindowDays = 60

    public var supplements: [Supplement]
    public var intakes: [SupplementIntake]
    public var trainingWeekdays: Set<Weekday>
    /// Les jours de la semaine datée (déplacements du Planning, règles anti-interférence, spec M6 §4 et §9), par minuit
    /// local : vrai quand une séance y est prévue. Un jour présent ici remplace `trainingWeekdays`.
    public var plannedTrainingDays: [Date: Bool]
    /// Les séances récentes, toutes sortes et tous statuts ; le planificateur choisit celles qui comptent.
    public var sessions: [WorkoutSession]
    /// L'heure habituelle d'endormissement (`HabitualBedtime`), en minutes après minuit ; `nil` sous 5 nuits.
    public var habitualBedtimeMinutes: Int?
    /// Les compléments « au coucher » qui suivent les nuits.
    public var followingNights: Set<UUID>
    public var calendar: Calendar

    public init(supplements: [Supplement], intakes: [SupplementIntake], trainingWeekdays: Set<Weekday>,
                plannedTrainingDays: [Date: Bool] = [:], sessions: [WorkoutSession], habitualBedtimeMinutes: Int? = nil,
                followingNights: Set<UUID> = [], calendar: Calendar) {
        self.supplements = supplements
        self.intakes = intakes
        self.trainingWeekdays = trainingWeekdays
        self.plannedTrainingDays = plannedTrainingDays
        self.sessions = sessions
        self.habitualBedtimeMinutes = habitualBedtimeMinutes
        self.followingNights = followingNights
        self.calendar = calendar
    }

    /// Les jours où le programme place une routine, lundi = indice 0 de `weekLayout`.
    public static func trainingWeekdays(of program: Program?) -> Set<Weekday> {
        guard let program else { return [] }
        return Set(program.weekLayout.enumerated().compactMap { index, routine in
            routine != nil && Weekday.allCases.indices.contains(index) ? Weekday.allCases[index] : nil
        })
    }

    /// Les jours de `overrides` qui valent pour `program`, par minuit local : vrai quand la ligne y place une séance.
    public static func plannedTrainingDays(of program: Program?, overrides: [ScheduledDay],
                                           calendar: Calendar) -> [Date: Bool] {
        guard let program else { return [:] }
        var days: [Date: Bool] = [:]
        for line in overrides where line.programID == nil || line.programID == program.id {
            let day = calendar.startOfDay(for: line.date)
            days[day] = TodayPlanner.routineDay(of: program, on: day, calendar: calendar, overrides: overrides) != nil
        }
        return days
    }

    // MARK: - Jour

    /// Les compléments dus ce jour-là, par moment, heure prévue puis ordre.
    public func items(on day: Date) -> [SupplementDueItem] {
        let start = calendar.startOfDay(for: day)
        let finishedEnd = workoutEndMinutes(on: start)
        return supplements.filter { isDue($0, on: start) }.map { supplement in
            let minutes = plannedMinutes(of: supplement, on: start)
            return SupplementDueItem(supplement: supplement, moment: Self.moment(of: supplement, plannedMinutes: minutes),
                                     plannedMinutes: minutes, intake: latestIntake(of: supplement.id, on: start),
                                     isWorkoutFinished: supplement.timing == .afterWorkout && finishedEnd != nil)
        }
        .sorted { lhs, rhs in
            if lhs.moment != rhs.moment { return lhs.moment < rhs.moment }
            if lhs.plannedMinutes != rhs.plannedMinutes { return lhs.plannedMinutes < rhs.plannedMinutes }
            return lhs.supplement.order < rhs.supplement.order
        }
    }

    /// Le complément est-il dû ce jour-là : pas archivé, déjà créé, et prévu ce jour de la semaine.
    public func isDue(_ supplement: Supplement, on day: Date) -> Bool {
        let start = calendar.startOfDay(for: day)
        guard !supplement.isArchived, calendar.startOfDay(for: supplement.createdAt) <= start else { return false }
        switch supplement.days {
        case .everyDay: return true
        case .custom: return supplement.customWeekdays.contains(Weekday(date: start, calendar: calendar))
        case .trainingDays: return isTrainingDay(start)
        }
    }

    /// Un jour d'entraînement : la semaine réelle y place une routine (la semaine datée, sinon la semaine type), ou une séance
    /// terminée ou en cours y a commencé.
    public func isTrainingDay(_ day: Date) -> Bool {
        let planned = plannedTrainingDays[calendar.startOfDay(for: day)]
            ?? trainingWeekdays.contains(Weekday(date: day, calendar: calendar))
        return planned || !trainingSessions(on: day).isEmpty
    }

    /// La dernière prise du complément ce jour-là.
    public func latestIntake(of supplementID: UUID, on day: Date) -> SupplementIntake? {
        intakes.filter { $0.supplementID == supplementID && calendar.isDate($0.takenAt, inSameDayAs: day) }
            .max { $0.takenAt < $1.takenAt }
    }

    /// L'heure prévue du complément ce jour-là, en minutes après minuit (spec M5 §4).
    public func plannedMinutes(of supplement: Supplement, on day: Date) -> Int {
        switch supplement.timing {
        case .fixedTime: return supplement.timeOfDayMinutes ?? 8 * 60
        case .bedtime: return bedtimeMinutes(of: supplement)
        case .beforeWorkout: return max(0, workoutStartMinutes(on: day) - Self.beforeWorkoutLeadMinutes)
        case .afterWorkout:
            return workoutEndMinutes(on: day) ?? min(24 * 60 - 1, workoutStartMinutes(on: day) + Self.assumedSessionMinutes)
        }
    }

    /// Vrai quand le complément « au coucher » suit les nuits et qu'il y en a assez pour une heure habituelle.
    public func followsNights(_ supplement: Supplement) -> Bool {
        supplement.timing == .bedtime && followingNights.contains(supplement.id) && habitualBedtimeMinutes != nil
    }

    /// L'heure d'un complément « au coucher » : 30 min avant l'heure habituelle d'endormissement s'il suit les nuits et qu'il y
    /// en a assez, sinon son heure fixe (22:30 sans heure).
    private func bedtimeMinutes(of supplement: Supplement) -> Int {
        if followingNights.contains(supplement.id), let habitualBedtimeMinutes {
            return HabitualBedtime.reminderMinutes(habitual: habitualBedtimeMinutes)
        }
        return supplement.timeOfDayMinutes ?? 22 * 60 + 30
    }

    /// Le moment d'affichage d'un complément à cette heure.
    public static func moment(of supplement: Supplement, plannedMinutes: Int) -> SupplementMoment {
        switch supplement.timing {
        case .beforeWorkout, .afterWorkout: .workout
        case .bedtime: .evening
        case .fixedTime:
            switch plannedMinutes {
            case ..<(12 * 60): .morning
            case ..<(18 * 60): .afternoon
            default: .evening
            }
        }
    }

    // MARK: - Séance

    /// L'heure de début de la séance du jour si elle a commencé, sinon l'heure habituelle.
    public func workoutStartMinutes(on day: Date) -> Int {
        if let first = trainingSessions(on: day).min(by: { $0.startedAt < $1.startedAt }) {
            return minutes(of: first.startedAt)
        }
        return habitualSessionMinutes(before: day)
    }

    /// L'heure de fin de la dernière séance terminée ce jour-là ; `nil` tant qu'aucune n'est finie.
    public func workoutEndMinutes(on day: Date) -> Int? {
        workoutEnd(on: day).map(minutes(of:))
    }

    /// La fin de la dernière séance terminée ce jour-là.
    public func workoutEnd(on day: Date) -> Date? {
        trainingSessions(on: day).filter { $0.status == .completed }.compactMap(\.endedAt).max()
    }

    /// La médiane des débuts des 10 dernières séances de musculation terminées sur 60 jours avant ce jour, au quart d'heure
    /// près ; 18:00 sans historique.
    public func habitualSessionMinutes(before day: Date) -> Int {
        let start = calendar.startOfDay(for: day)
        guard let windowStart = calendar.date(byAdding: .day, value: -Self.habitualWindowDays, to: start) else {
            return Self.defaultSessionMinutes
        }
        let recent = sessions
            .filter { $0.kind == .strength && $0.status == .completed && $0.startedAt >= windowStart && $0.startedAt < start }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(Self.habitualSampleSize)
            .map { minutes(of: $0.startedAt) }
            .sorted()
        guard !recent.isEmpty else { return Self.defaultSessionMinutes }
        let middle = recent.count / 2
        let median = recent.count.isMultiple(of: 2) ? (recent[middle - 1] + recent[middle]) / 2 : recent[middle]
        return Int((Double(median) / 15).rounded()) * 15
    }

    /// Les séances de musculation terminées ou en cours commencées ce jour-là. Une course lue d'Apple Santé (spec M6 §3) n'est
    /// pas une séance Pulse : elle ne rend pas un jour « d'entraînement » et ne déplace pas les rappels autour de la séance.
    private func trainingSessions(on day: Date) -> [WorkoutSession] {
        sessions.filter {
            $0.kind == .strength && ($0.status == .completed || $0.status == .inProgress)
                && calendar.isDate($0.startedAt, inSameDayAs: day)
        }
    }

    private func minutes(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
