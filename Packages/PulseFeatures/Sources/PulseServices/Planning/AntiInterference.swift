import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Ce que les règles anti-interférence lisent pour la semaine en cours (spec M6 §9).
public struct AntiInterferenceInput: Sendable {
    public var program: Program
    public var profile: UserProfile
    /// Les lignes de la semaine datée en cours, toutes raisons confondues.
    public var lines: [ScheduledDay]
    /// Les séances depuis 8 jours avant aujourd'hui jusqu'à la fin de la semaine.
    public var sessions: [WorkoutSession]
    public var nights: [NightSample]
    public var directory: ExerciseDirectory
    public var calendar: Calendar
    public var now: Date

    public init(program: Program, profile: UserProfile, lines: [ScheduledDay], sessions: [WorkoutSession], nights: [NightSample],
                directory: ExerciseDirectory, calendar: Calendar, now: Date) {
        self.program = program
        self.profile = profile
        self.lines = lines
        self.sessions = sessions
        self.nights = nights
        self.directory = directory
        self.calendar = calendar
        self.now = now
    }
}

/// Une ligne qu'une règle veut sur un jour de la semaine datée.
public struct RuleLine: Sendable, Equatable {
    public var date: Date
    public var routine: RoutineDay?
    public var movedFromDate: Date?
    public var reason: MoveReason
    public var text: String

    public init(date: Date, routine: RoutineDay?, movedFromDate: Date? = nil, reason: MoveReason, text: String) {
        self.date = date
        self.routine = routine
        self.movedFromDate = movedFromDate
        self.reason = reason
        self.text = text
    }
}

/// Ce que les règles décident : les jours qu'elles gèrent et les lignes qu'elles y veulent.
public struct AntiInterferencePlan: Sendable, Equatable {
    /// Aujourd'hui et après, sans séance faite ni ligne `.user` : les seuls jours où une ligne de règle s'écrit ou s'efface.
    public var managedDates: [Date]
    public var lines: [RuleLine]

    public init(managedDates: [Date], lines: [RuleLine]) {
        self.managedDates = managedDates
        self.lines = lines
    }
}

/// Les trois règles anti-interférence (spec M6 §9). Elles partent de la semaine type et des lignes `.user`, et ignorent leurs
/// propres lignes des jours qu'elles gèrent : le résultat ne dépend que de la semaine, des séances et des nuits.
public enum AntiInterference {
    /// Le sous-score sommeil sous lequel commence la fatigue modérée.
    public static let sleepThreshold = 65.0
    public static let minimumNights = 4
    public static let daysWithoutRest = 7

    public static func plan(_ input: AntiInterferenceInput) -> AntiInterferencePlan {
        var draft = Draft(input)
        let disabled = Set(input.profile.antiInterferenceRulesDisabled)
        if !disabled.contains(.fullRestDay), needsRestDay(input, today: draft.today) {
            draft.placeRestDay()
        }
        if !disabled.contains(.noIntenseRunAfterHeavyLegs) {
            draft.spaceIntenseRuns()
        }
        return AntiInterferencePlan(managedDates: draft.managedDates, lines: draft.lines)
    }

    /// Vrai pour une ligne écrite par une règle.
    public static func isRule(_ line: ScheduledDay) -> Bool {
        line.moveReason.map { $0 != .user } ?? false
    }

    /// Une course facile écrite par la règle des jambes lourdes, sans déplacement : la course prévue y est remplacée par une
    /// sortie facile.
    public static func isEasedRun(_ line: ScheduledDay) -> Bool {
        line.moveReason == .antiInterferenceAfterHeavyLegs && line.kind == .run && line.movedFromDate == nil
    }

    /// Le rappel « au moins 6 h entre les deux » : aujourd'hui, une séance prévue pas encore faite et une séance de l'autre
    /// discipline déjà faite.
    public static func needsSpacing(_ day: PlanningDay) -> Bool {
        guard day.isToday, let routine = day.routine, day.state != .done else { return false }
        let other: SessionKind = routine.kind == .strength ? .run : .strength
        return day.sessions.contains { $0.kind == other }
    }

    /// Les 7 jours d'avant ont tous eu une séance, et le sommeil des 7 dernières nuits, noté contre l'objectif du profil, est en
    /// moyenne sous la fatigue modérée.
    static func needsRestDay(_ input: AntiInterferenceInput, today: Date) -> Bool {
        let calendar = input.calendar
        let completed = input.sessions.filter(WeekSchedule.shows)
        let busy = (1...daysWithoutRest).allSatisfy { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return completed.contains { calendar.isDate($0.startedAt, inSameDayAs: day) }
        }
        guard busy, let since = calendar.date(byAdding: .day, value: -(daysWithoutRest - 1), to: today) else { return false }
        let goal = SleepGoal.minutes(of: input.profile)
        let scores = input.nights.filter { $0.day >= since && $0.day <= today }.compactMap { night -> Double? in
            guard let sleep = night.sleep, sleep.asleepMinutes > 0 else { return nil }
            return SleepScorer.score(asleepMinutes: sleep.asleepMinutes, deepMinutes: sleep.deepMinutes, targetMinutes: goal)
        }
        guard scores.count >= minimumNights else { return false }
        return scores.reduce(0, +) / Double(scores.count) < sleepThreshold
    }
}

/// La semaine en cours de calcul : la séance de chaque jour, les jours que les règles ne touchent pas, et les lignes écrites.
private struct Draft {
    let input: AntiInterferenceInput
    let today: Date
    let dates: [Date]
    let completed: [WorkoutSession]
    /// Passé, validé, ou fixé par l'utilisateur ; les deux jours d'un déplacement de règle le sont ensemble.
    let locked: [Bool]
    var routines: [RoutineDay?]
    /// Déjà décidé par une règle : une autre règle n'y revient pas.
    var ruled: [Bool]
    var lines: [RuleLine] = []

    init(_ input: AntiInterferenceInput) {
        self.input = input
        let calendar = input.calendar
        today = calendar.startOfDay(for: input.now)
        let weekStart = WeekSchedule.weekStart(of: today, calendar: calendar)
        let dates = (0..<Weekday.allCases.count).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        self.dates = dates
        let completed = input.sessions.filter(WeekSchedule.shows)
        self.completed = completed
        let program = input.program
        let lines = input.lines.filter { $0.programID == nil || $0.programID == program.id }
        let locked = Self.locked(dates: dates, lines: lines, input: input, completed: completed, today: today)
        self.locked = locked
        // Les lignes de règle des jours fixés restent : elles disent ce qui était prévu ce jour-là.
        let base = lines.filter { line in
            !AntiInterference.isRule(line) || dates.indices.contains { locked[$0] && calendar.isDate(dates[$0], inSameDayAs: line.date) }
        }
        routines = dates.map { TodayPlanner.routineDay(of: program, on: $0, calendar: calendar, overrides: base) }
        ruled = Array(repeating: false, count: dates.count)
    }

    /// Un jour passé, validé tel qu'il est prévu maintenant (spec M6 §4), ou portant une ligne `.user`. Un déplacement de règle
    /// dont un jour est fixé garde ses deux jours : sinon l'autre jour serait recalculé, et la course perdue ou doublée.
    private static func locked(dates: [Date], lines: [ScheduledDay], input: AntiInterferenceInput, completed: [WorkoutSession],
                               today: Date) -> [Bool] {
        let calendar = input.calendar
        let current = ScheduleContext(program: input.program, overrides: lines, sessions: completed,
                                      restWeekdays: input.profile.restWeekdays, calendar: calendar)
        var locked = dates.map { date in
            date < today || WeekSchedule.day(on: date, context: current, today: today).state == .done
                || lines.contains { !AntiInterference.isRule($0) && calendar.isDate($0.date, inSameDayAs: date) }
        }
        for line in lines where AntiInterference.isRule(line) {
            guard let origin = line.movedFromDate,
                  let target = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: line.date) }),
                  let source = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: origin) }),
                  locked[target] || locked[source] else { continue }
            locked[target] = true
            locked[source] = true
        }
        return locked
    }

    var managedDates: [Date] {
        dates.indices.filter { !locked[$0] }.map { dates[$0] }
    }

    private func isFree(_ index: Int) -> Bool {
        !locked[index] && !ruled[index]
    }

    /// Règle 3 : le prochain jour prévu de la semaine, aujourd'hui compris, devient un repos. Si ce jour est fixé (un refus,
    /// une séance déjà faite), la règle ne cherche pas plus loin : le repos ne glisse pas de jour en jour.
    mutating func placeRestDay() {
        guard let index = dates.indices.first(where: { dates[$0] >= today && routines[$0] != nil }), isFree(index) else { return }
        routines[index] = nil
        ruled[index] = true
        lines.append(RuleLine(date: dates[index], routine: nil, reason: .antiInterferenceRestDay,
                              text: String(localized: "Repos placé : 7 jours sans repos et sommeil court", bundle: .module)))
    }

    /// Règle 1 : un fractionné ou une sortie longue le jour même ou le lendemain d'une séance de jambes lourde change de jour,
    /// ou devient une sortie facile.
    mutating func spaceIntenseRuns() {
        for index in dates.indices where isFree(index) {
            guard let run = routines[index], run.kind == .run, run.runType == .intervals || run.runType == .long,
                  followsHeavyLegs(dates[index]) else { continue }
            if let target = dates.indices.first(where: { isFreeForRun($0, other: index) }) {
                routines[target] = run
                routines[index] = nil
                ruled[target] = true
                ruled[index] = true
                lines.append(RuleLine(date: dates[index], routine: nil, reason: .antiInterferenceAfterHeavyLegs,
                                      text: String(localized: "Course déplacée : 36 h après les jambes", bundle: .module)))
                lines.append(RuleLine(date: dates[target], routine: run, movedFromDate: dates[index],
                                      reason: .antiInterferenceAfterHeavyLegs,
                                      text: String(localized: "Déplacée : 36 h après les jambes", bundle: .module)))
            } else {
                ruled[index] = true
                lines.append(RuleLine(date: dates[index], routine: run, reason: .antiInterferenceAfterHeavyLegs,
                                      text: String(localized: "Sortie facile : 36 h après les jambes", bundle: .module)))
            }
        }
    }

    /// Un jour de repos qui n'est pas un repos obligatoire, sans séance de jambes lourde la veille ni le jour même.
    private func isFreeForRun(_ index: Int, other: Int) -> Bool {
        let weekday = Weekday(date: dates[index], calendar: input.calendar)
        return index != other && isFree(index) && routines[index] == nil && !input.profile.restWeekdays.contains(weekday)
            && !followsHeavyLegs(dates[index])
    }

    /// Une séance de jambes lourde, faite ou prévue, le jour même ou la veille de `date`.
    private func followsHeavyLegs(_ date: Date) -> Bool {
        let calendar = input.calendar
        guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        return [previous, date].contains { isHeavyLegsDay($0) }
    }

    private func isHeavyLegsDay(_ date: Date) -> Bool {
        let calendar = input.calendar
        let done = completed.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
        if done.contains(where: { HeavyLegs.isHeavy($0, directory: input.directory) }) { return true }
        // Un jour passé ne compte que par ce qui a été fait ; un jour à venir aussi par ce qui est prévu.
        guard date >= today, done.isEmpty, let index = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }),
              let routine = routines[index] else { return false }
        return HeavyLegs.isHeavy(routine, directory: input.directory)
    }
}
