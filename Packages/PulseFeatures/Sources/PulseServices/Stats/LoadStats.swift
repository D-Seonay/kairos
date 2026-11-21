import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Une barre de charge : minutes × RPE de la période (jour ou semaine qui commence à `start`), par discipline.
public struct LoadBar: Sendable, Equatable, Identifiable {
    public var start: Date
    public var strength: Double
    public var run: Double
    public var ride: Double

    public var id: Date { start }

    public init(start: Date, strength: Double, run: Double, ride: Double) {
        self.start = start
        self.strength = strength
        self.run = run
        self.ride = ride
    }
}

public struct LoadTotals: Sendable, Equatable {
    public var tonnageKg: Double
    public var runMeters: Double
    public var rideMeters: Double
    public var minutes: Double
    public var sessions: Int
    /// La part de la musculation dans la charge, de 0 à 1 ; `nil` sans charge.
    public var strengthShare: Double?

    public init(tonnageKg: Double, runMeters: Double, rideMeters: Double, minutes: Double, sessions: Int, strengthShare: Double?) {
        self.tonnageKg = tonnageKg
        self.runMeters = runMeters
        self.rideMeters = rideMeters
        self.minutes = minutes
        self.sessions = sessions
        self.strengthShare = strengthShare
    }
}

/// La phrase de bilan sous la courbe, choisie par règle (spec M7 §6).
public enum LoadVerdict: Sendable, Equatable {
    case deload(until: Date)
    case optimal(weeks: Int)
    case elevated(days: Int)
    case low
    case steady
}

/// La vue Charge : ratio du jour, courbe, barres par discipline, totaux et bilan (spec M7 §6).
public struct LoadStats: Sendable, Equatable {
    public var today: ACWRResult?
    /// La charge aiguë (7 jours) au même jour de la semaine d'avant, pour la comparaison de la tuile ; `nil` sans ratio ce jour-là.
    public var acuteWeekBefore: Double?
    public var ratioPoints: [StatsPoint]
    /// Les jours qui manquent avant le premier ratio ; `nil` dès 28 jours d'historique.
    public var daysUntilRatio: Int?
    public var verdict: LoadVerdict?
    public var bars: [LoadBar]
    public var totals: LoadTotals

    /// Les bornes de la zone optimale (`ACWRZone`).
    private static let optimalRange = 0.8...1.3

    // swiftlint:disable:next function_parameter_count
    public static func make(sessions: [WorkoutSession], onboardingCompletedAt: Date?, deloadUntil: Date?, period: StatsPeriod,
                            now: Date, calendar: Calendar) -> LoadStats {
        // Mêmes séances et même début d'historique que `TrainingLoad.acwr`.
        let historyStart = ([onboardingCompletedAt] + sessions.map(\.startedAt)).compactMap { $0 }.min() ?? now
        let counted = sessions
            .filter { $0.status == .completed || $0.status == .abandoned }
            .compactMap { session in TrainingLoad.loadSession(session).map { (session: session, load: $0) } }
        let ratios = DailyRatios(loads: counted.map(\.load), historyStart: historyStart, calendar: calendar)

        let today = TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: onboardingCompletedAt, now: now, calendar: calendar)
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let interval = period.interval(now: now, calendar: calendar)
        let inPeriod = counted.filter { interval.start <= $0.session.startedAt && $0.session.startedAt < interval.end }

        return LoadStats(
            today: today,
            acuteWeekBefore: ratios.result(on: weekBefore)?.acute,
            ratioPoints: ratioPoints(ratios: ratios, interval: interval, bucket: period.chartBucket, calendar: calendar),
            daysUntilRatio: daysUntilRatio(historyStart: historyStart, now: now, calendar: calendar),
            verdict: verdict(ratios: ratios, deloadUntil: deloadUntil, now: now, calendar: calendar),
            bars: bars(of: inPeriod, interval: interval, bucket: period.loadBucket, calendar: calendar),
            totals: totals(of: inPeriod))
    }

    // MARK: - Courbe

    /// Un point par jour (un par dimanche sur un an), pour les seuls jours où le ratio existe.
    private static func ratioPoints(ratios: DailyRatios, interval: DateInterval, bucket: StatsBucket, calendar: Calendar) -> [StatsPoint] {
        days(in: interval, calendar: calendar).compactMap { day in
            if bucket == .week, calendar.component(.weekday, from: day) != 1 { return nil }
            return ratios.result(on: day).map { StatsPoint(date: day, value: $0.ratio) }
        }
    }

    private static func daysUntilRatio(historyStart: Date, now: Date, calendar: Calendar) -> Int? {
        let first = calendar.startOfDay(for: historyStart)
        let elapsed = calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: now)).day ?? 0
        let missing = LoadCalculator.requiredHistoryDays - 1 - elapsed
        return missing > 0 ? missing : nil
    }

    // MARK: - Bilan

    /// La décharge en cours l'emporte ; sinon le bilan suit le ratio du jour, avec la durée de la série en cours.
    private static func verdict(ratios: DailyRatios, deloadUntil: Date?, now: Date, calendar: Calendar) -> LoadVerdict? {
        if let deloadUntil, deloadUntil >= calendar.startOfDay(for: now) { return .deload(until: deloadUntil) }
        guard let ratio = ratios.result(on: now)?.ratio else { return nil }
        if ratio < optimalRange.lowerBound { return .low }
        if ratio > optimalRange.upperBound {
            return .elevated(days: streak(of: ratios, endingOn: now, calendar: calendar) { $0 > optimalRange.upperBound })
        }
        let weeks = streak(of: ratios, endingOn: now, calendar: calendar) { optimalRange.contains($0) } / 7
        return weeks >= 1 ? .optimal(weeks: weeks) : .steady
    }

    /// Le nombre de jours d'affilée, jusqu'à aujourd'hui, dont le ratio vérifie `matches` ; la série s'arrête au premier jour
    /// sans ratio.
    private static func streak(of ratios: DailyRatios, endingOn now: Date, calendar: Calendar, matches: (Double) -> Bool) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: now)
        while let ratio = ratios.result(on: day)?.ratio, matches(ratio) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Barres et totaux

    /// Une barre par grain sur toute la période, les grains vides compris. Seules les séances de la période comptent : la
    /// première semaine d'une période qui commence en milieu de semaine est donc partielle.
    private static func bars(of sessions: [(session: WorkoutSession, load: LoadSession)], interval: DateInterval, bucket: StatsBucket,
                             calendar: Calendar) -> [LoadBar] {
        func start(of date: Date) -> Date {
            bucket == .day ? calendar.startOfDay(for: date) : WeekSchedule.weekStart(of: date, calendar: calendar)
        }
        var bars: [Date: LoadBar] = [:]
        var cursor = start(of: interval.start)
        let step = bucket == .day ? 1 : 7
        while cursor < interval.end {
            bars[cursor] = LoadBar(start: cursor, strength: 0, run: 0, ride: 0)
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = next
        }
        for (session, load) in sessions {
            let key = start(of: session.startedAt)
            switch session.kind {
            case .strength: bars[key]?.strength += load.load
            case .run: bars[key]?.run += load.load
            case .ride: bars[key]?.ride += load.load
            }
        }
        return bars.values.sorted { $0.start < $1.start }
    }

    private static func totals(of sessions: [(session: WorkoutSession, load: LoadSession)]) -> LoadTotals {
        let totalLoad = sessions.reduce(0) { $0 + $1.load.load }
        let strengthLoad = sessions.filter { $0.session.kind == .strength }.reduce(0) { $0 + $1.load.load }
        return LoadTotals(
            tonnageKg: sessions.filter { $0.session.kind == .strength }.reduce(0) { $0 + $1.session.tonnageKg },
            runMeters: sessions.filter { $0.session.kind == .run }.reduce(0) { $0 + ($1.session.distanceMeters ?? 0) },
            rideMeters: sessions.filter { $0.session.kind == .ride }.reduce(0) { $0 + ($1.session.distanceMeters ?? 0) },
            minutes: sessions.reduce(0) { $0 + $1.load.minutes },
            sessions: sessions.count,
            strengthShare: totalLoad > 0 ? strengthLoad / totalLoad : nil)
    }

    private static func days(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var day = interval.start
        while day < interval.end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

/// Le ratio aigu / chronique d'un jour donné, calculé par `LoadCalculator` sur les seules séances de ses 28 jours : un
/// calcul par jour de la période ne relit pas tout l'historique.
private struct DailyRatios {
    let loads: [LoadSession]
    let historyStart: Date
    let calendar: Calendar

    func result(on day: Date) -> ACWRResult? {
        let dayStart = calendar.startOfDay(for: day)
        guard let windowStart = calendar.date(byAdding: .day, value: -(LoadCalculator.requiredHistoryDays - 1), to: dayStart),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let window = loads.filter { windowStart <= $0.date && $0.date < dayEnd }
        return LoadCalculator(calendar: calendar).acwr(sessions: window, asOf: dayStart, historyStart: historyStart)
    }
}
