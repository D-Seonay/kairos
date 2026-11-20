import Foundation
import PulseDomain

/// Une semaine du pilier de série : ses séances comptées face à l'objectif.
public struct StreakWeek: Sendable, Equatable, Identifiable {
    /// Le lundi de la semaine, à minuit.
    public var weekStart: Date
    public var count: Int
    public var target: Int
    public var isCurrent: Bool

    public init(weekStart: Date, count: Int, target: Int, isCurrent: Bool) {
        self.weekStart = weekStart
        self.count = count
        self.target = target
        self.isCurrent = isCurrent
    }

    public var id: Date { weekStart }

    public var isSuccess: Bool { count >= target }

    /// La part de l'objectif atteinte, entre 0 et 1.
    public var progress: Double {
        target > 0 ? min(1, Double(count) / Double(target)) : 1
    }
}

/// La série : les semaines réussies d'affilée et le pilier des dernières semaines (spec M6 §5).
public struct StreakSummary: Sendable, Equatable {
    /// Les semaines réussies consécutives jusqu'à la semaine dernière, plus la semaine en cours si elle est déjà réussie.
    public var streak: Int
    /// Les `pillarWeeks` dernières semaines, de la plus ancienne à la semaine en cours.
    public var weeks: [StreakWeek]

    public init(streak: Int, weeks: [StreakWeek]) {
        self.streak = streak
        self.weeks = weeks
    }

    public var currentWeek: StreakWeek? { weeks.last }
}

public enum WeekStreak {
    /// La hauteur du pilier.
    public static let pillarWeeks = 12

    /// L'objectif de la semaine : les séances de la semaine type du programme, sinon les jours d'entraînement du profil ; au
    /// moins 1.
    public static func target(program: Program?, profile: UserProfile?) -> Int {
        max(1, program?.sessionsPerWeek ?? profile?.trainingDaysPerWeek ?? 1)
    }

    /// Une séance de musculation terminée, de toute source, ou une course : le vélo et la marche ne comptent pas.
    public static func counts(_ session: WorkoutSession) -> Bool {
        session.status == .completed && (session.kind == .strength || session.kind == .run)
    }

    /// `historyStart` : la fin de l'onboarding ou la première séance, la plus ancienne des deux ; la série ne remonte pas
    /// avant sa semaine.
    public static func summary(sessions: [WorkoutSession], target: Int, historyStart: Date?, now: Date,
                               calendar: Calendar) -> StreakSummary {
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        var perWeek = [Date: Int]()
        for session in sessions where Self.counts(session) {
            perWeek[WeekSchedule.weekStart(of: session.startedAt, calendar: calendar), default: 0] += 1
        }
        func week(_ offset: Int) -> StreakWeek? {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: current) else { return nil }
            return StreakWeek(weekStart: start, count: perWeek[start] ?? 0, target: target, isCurrent: offset == 0)
        }
        let weeks = (0..<pillarWeeks).reversed().compactMap(week)
        guard let historyStart else { return StreakSummary(streak: 0, weeks: weeks) }
        let firstWeek = WeekSchedule.weekStart(of: historyStart, calendar: calendar)
        var streak = (week(0)?.isSuccess ?? false) ? 1 : 0
        var offset = 1
        while let past = week(offset), past.weekStart >= firstWeek, past.isSuccess {
            streak += 1
            offset += 1
        }
        return StreakSummary(streak: streak, weeks: weeks)
    }
}
