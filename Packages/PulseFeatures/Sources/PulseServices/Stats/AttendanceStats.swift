import Foundation
import PulseDomain

/// Une case de la matrice d'assiduité : un jour et son niveau d'intensité, de 0 (aucune séance ni sortie à vélo) à 4.
public struct AttendanceDay: Sendable, Equatable, Identifiable {
    public var date: Date
    public var level: Int
    public var isFuture: Bool
    /// Un autre entraînement d'Apple Santé ce jour-là (natation, HIIT, sport…, `HealthActivities`) : montré d'une marque neutre
    /// quand aucune séance n'en fait déjà un jour entraîné. Il ne compte ni dans le niveau ni dans la série.
    public var hasActivity: Bool

    public var id: Date { date }

    public init(date: Date, level: Int, isFuture: Bool, hasActivity: Bool = false) {
        self.date = date
        self.level = level
        self.isFuture = isFuture
        self.hasActivity = hasActivity
    }
}

/// La vue Assiduité : matrice des 16 dernières semaines, série, meilleure série et tuiles de la période (spec M7 §9).
public struct AttendanceStats: Sendable, Equatable {
    public static let matrixWeeks = 16

    /// 16 colonnes de 7 jours (lundi → dimanche), la semaine en cours en dernier.
    public var weeks: [[AttendanceDay]]
    public var streak: StreakSummary
    public var best: BestStreak?
    public var sessionsInPeriod: Int
    public var sessionsTotal: Int
    public var firstSession: Date?
    /// La durée moyenne des séances de la période ; `nil` sans séance qui ait une durée.
    public var averageMinutes: Double?
    /// L'heure de début la plus fréquente sur la période (0…23) ; `nil` sans séance.
    public var usualHour: Int?
    /// Les semaines réussies sur celles de la période, de 0 à 1 ; `nil` sans semaine jugeable.
    public var regularity: Double?

    // swiftlint:disable function_parameter_count
    /// `activities` : les débuts des autres entraînements d'Apple Santé, montrés dans la matrice seulement.
    public static func make(sessions: [WorkoutSession], activities: [Date] = [], target: Int, historyStart: Date?, period: StatsPeriod,
                            now: Date, calendar: Calendar) -> AttendanceStats {
        // Les tuiles comptent les mêmes séances que la série. La matrice montre en plus les vélos terminés : le vélo ne compte
        // pas pour la série (spec M6 §5), mais une sortie reste un jour d'activité.
        let counted = sessions.filter(WeekStreak.counts)
        let interval = period.interval(now: now, calendar: calendar)
        let inPeriod = counted.filter { interval.start <= $0.startedAt && $0.startedAt < interval.end }
        let minutes = inPeriod.compactMap { TrainingLoad.loadSession($0)?.minutes }

        return AttendanceStats(
            weeks: matrix(sessions.filter(showsInMatrix), activities: activities, now: now, calendar: calendar),
            streak: WeekStreak.summary(sessions: sessions, target: target, historyStart: historyStart, now: now, calendar: calendar),
            best: WeekStreak.best(sessions: sessions, target: target, historyStart: historyStart, now: now, calendar: calendar),
            sessionsInPeriod: inPeriod.count,
            sessionsTotal: counted.count,
            firstSession: counted.map(\.startedAt).min(),
            averageMinutes: minutes.isEmpty ? nil : minutes.reduce(0, +) / Double(minutes.count),
            usualHour: usualHour(of: inPeriod, calendar: calendar),
            regularity: regularity(sessions: sessions, target: target, historyStart: historyStart, interval: interval, now: now,
                                   calendar: calendar))
    }
    // swiftlint:enable function_parameter_count

    /// Une case de la matrice : une séance qui compte pour la série, ou un vélo terminé (lu d'Apple Santé). Les abandons restent
    /// hors de la matrice.
    public static func showsInMatrix(_ session: WorkoutSession) -> Bool {
        WeekStreak.counts(session) || (session.status == .completed && session.kind == .ride)
    }

    /// L'heure de début la plus fréquente, la plus tôt à égalité.
    private static func usualHour(of sessions: [WorkoutSession], calendar: Calendar) -> Int? {
        var perHour = [Int: Int]()
        for session in sessions {
            perHour[calendar.component(.hour, from: session.startedAt), default: 0] += 1
        }
        return perHour.min { ($1.value, $0.key) < ($0.value, $1.key) }?.key
    }

    // swiftlint:disable function_parameter_count
    /// Les semaines (lundi) qui chevauchent la période, sans remonter avant la semaine de `historyStart` ; la semaine en cours
    /// n'est jugée que si elle est déjà réussie.
    private static func regularity(sessions: [WorkoutSession], target: Int, historyStart: Date?, interval: DateInterval,
                                   now: Date, calendar: Calendar) -> Double? {
        guard let historyStart else { return nil }
        let perWeek = WeekStreak.weeklyCounts(sessions: sessions, calendar: calendar)
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        let firstWeek = WeekSchedule.weekStart(of: historyStart, calendar: calendar)
        var week = max(WeekSchedule.weekStart(of: interval.start, calendar: calendar), firstWeek)
        var total = 0
        var successful = 0
        while week <= current {
            let success = (perWeek[week] ?? 0) >= target
            if week < current || success {
                total += 1
                if success { successful += 1 }
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week), next > week else { break }
            week = next
        }
        return total > 0 ? Double(successful) / Double(total) : nil
    }
    // swiftlint:enable function_parameter_count

    /// Les 16 semaines qui finissent par la semaine en cours, de la plus ancienne à la plus récente, sur les séances `shown` et
    /// les autres entraînements `activities`.
    private static func matrix(_ shown: [WorkoutSession], activities: [Date], now: Date, calendar: Calendar) -> [[AttendanceDay]] {
        let today = calendar.startOfDay(for: now)
        let current = WeekSchedule.weekStart(of: now, calendar: calendar)
        let mondays = (0..<matrixWeeks).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: current) }
        let days = mondays.map { monday in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        }

        var loads = [Date: Double]()
        var trained = Set<Date>()
        for session in shown {
            let day = calendar.startOfDay(for: session.startedAt)
            trained.insert(day)
            loads[day, default: 0] += TrainingLoad.loadSession(session)?.load ?? 0
        }
        let window = Set(days.joined())
        let thresholds = quartiles(of: window.compactMap { loads[$0] }.filter { $0 > 0 })
        let active = Set(activities.map { calendar.startOfDay(for: $0) })

        return days.map { week in
            week.map { day in
                AttendanceDay(date: day, level: level(trained: trained.contains(day), load: loads[day] ?? 0, thresholds: thresholds),
                              isFuture: day > today, hasActivity: active.contains(day))
            }
        }
    }

    /// Les seuils q1, q2, q3 au rang le plus proche (25 %, 50 %, 75 %) ; vides sans charge.
    private static func quartiles(of loads: [Double]) -> [Double] {
        let sorted = loads.sorted()
        guard !sorted.isEmpty else { return [] }
        return [0.25, 0.5, 0.75].map { sorted[max(0, Int((Double(sorted.count) * $0).rounded(.up)) - 1)] }
    }

    /// 0 sans séance ; 1 pour un jour entraîné sans charge calculable ; sinon 1 à 4 selon les seuils.
    private static func level(trained: Bool, load: Double, thresholds: [Double]) -> Int {
        guard trained else { return 0 }
        guard load > 0, thresholds.count == 3 else { return 1 }
        return 1 + thresholds.filter { load > $0 }.count
    }
}
