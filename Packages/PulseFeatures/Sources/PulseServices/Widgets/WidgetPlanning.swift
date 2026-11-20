import Foundation
import PulseContent
import PulseDomain

/// Ce que les widgets Série, Semaine et Prochaine séance lisent de la semaine datée (spec M6 §11).
public struct WidgetPlanning: Sendable, Equatable {
    public var streak: WidgetStreak
    public var week: [WidgetDay]
    public var nextSession: WidgetNextSession?
    public var loadRatio: Double?

    public init(streak: WidgetStreak, week: [WidgetDay], nextSession: WidgetNextSession?, loadRatio: Double?) {
        self.streak = streak
        self.week = week
        self.nextSession = nextSession
        self.loadRatio = loadRatio
    }

    /// La prochaine séance est cherchée dans les 7 jours après aujourd'hui : dans la semaine datée, puis dans la semaine type.
    public static func make(overview: PlanningOverview, loadRatio: Double?, now: Date, calendar: Calendar) -> WidgetPlanning {
        let current = overview.streak.currentWeek
        let streak = WidgetStreak(weeks: overview.streak.streak, completed: current?.count ?? 0,
                                  target: current?.target ?? WeekStreak.target(program: overview.program, profile: overview.profile))
        let week = overview.days.map { day in
            WidgetDay(date: day.date, kind: kind(of: day.routine), state: state(of: day.state), isToday: day.isToday)
        }
        return WidgetPlanning(streak: streak, week: week, nextSession: nextSession(overview: overview, now: now, calendar: calendar),
                              loadRatio: loadRatio)
    }

    private static func nextSession(overview: PlanningOverview, now: Date, calendar: Calendar) -> WidgetNextSession? {
        guard let program = overview.program else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in 1...Weekday.allCases.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let routine = overview.days.first { calendar.isDate($0.date, inSameDayAs: date) }.map(\.routine)
                ?? TodayPlanner.routineDay(of: program, on: Weekday(date: date, calendar: calendar))
            if let routine {
                return WidgetNextSession(title: routine.name, date: date, kind: kind(of: routine), detail: detail(of: routine))
            }
        }
        return nil
    }

    static func kind(of routine: RoutineDay?) -> WidgetDayKind {
        switch routine?.kind {
        case .strength: .strength
        case .run: .run
        case nil: .rest
        }
    }

    static func state(of state: PlanningDayState) -> WidgetDayState {
        switch state {
        case .done: .done
        case .missed: .missed
        case .planned: .planned
        case .rest, .mandatoryRest: .rest
        }
    }

    /// « 5 exercices · 16 séries » pour la musculation, « Sortie facile · 45 min » pour une course.
    static func detail(of routine: RoutineDay) -> String? {
        switch routine.kind {
        case .strength:
            guard !routine.exercises.isEmpty else { return nil }
            let sets = routine.exercises.reduce(0) { $0 + $1.sets }
            return String(localized: "\(routine.exercises.count) exercices · \(sets) séries", bundle: .module)
        case .run:
            var parts = [routine.runType?.localizedName ?? String(localized: "Course", bundle: .module)]
            if let minutes = routine.runTargetMinutes {
                parts.append(String(localized: "\(minutes) min", bundle: .module))
            } else if let km = routine.runTargetKm {
                let distance = km.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "fr_FR")))
                parts.append(String(localized: "\(distance) km", bundle: .module))
            }
            return parts.joined(separator: " · ")
        }
    }
}

extension WidgetSnapshot {
    /// L'instantané avec la série, la semaine, la prochaine séance et la charge.
    public func adding(_ planning: WidgetPlanning?) -> WidgetSnapshot {
        guard let planning else { return self }
        var snapshot = self
        snapshot.streak = planning.streak
        snapshot.week = planning.week
        snapshot.nextSession = planning.nextSession
        snapshot.loadRatio = planning.loadRatio
        return snapshot
    }
}

extension PlanningService {
    /// La semaine datée, la série et la charge des 28 derniers jours, pour les widgets.
    public func widgetPlanning() async throws -> WidgetPlanning {
        let overview = try await overview()
        let now = now()
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let sessions = try await workouts.sessions(from: start, to: end)
        let ratio = TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: overview.profile?.onboardingCompletedAt, now: now,
                                      calendar: calendar)?.ratio
        return WidgetPlanning.make(overview: overview, loadRatio: ratio, now: now, calendar: calendar)
    }
}
