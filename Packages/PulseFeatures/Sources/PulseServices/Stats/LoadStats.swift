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
    /// La charge (minutes × RPE) de la période seule, par discipline : les barres, elles, couvrent des semaines entières.
    public var strengthLoad: Double
    public var runLoad: Double
    public var rideLoad: Double

    public var totalLoad: Double { strengthLoad + runLoad + rideLoad }

    public init(tonnageKg: Double, runMeters: Double, rideMeters: Double, minutes: Double, sessions: Int, strengthShare: Double?,
                strengthLoad: Double = 0, runLoad: Double = 0, rideLoad: Double = 0) {
        self.tonnageKg = tonnageKg
        self.runMeters = runMeters
        self.rideMeters = rideMeters
        self.minutes = minutes
        self.sessions = sessions
        self.strengthShare = strengthShare
        self.strengthLoad = strengthLoad
        self.runLoad = runLoad
        self.rideLoad = rideLoad
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

    // swiftlint:disable:next function_parameter_count
    public static func make(sessions: [WorkoutSession], onboardingCompletedAt: Date?, deloadUntil: Date?, period: StatsPeriod,
                            now: Date, calendar: Calendar) -> LoadStats {
        // Mêmes séances et même début d'historique que `TrainingLoad.acwr`.
        let historyStart = ([onboardingCompletedAt] + sessions.map(\.startedAt)).compactMap { $0 }.min() ?? now
        let counted = sessions
            .filter { $0.status == .completed || $0.status == .abandoned }
            .map { CountedSession(session: $0, load: TrainingLoad.loadSession($0)) }
        let ratios = DailyRatios(loads: counted.compactMap(\.load), historyStart: historyStart, calendar: calendar)

        let today = TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: onboardingCompletedAt, now: now, calendar: calendar)
        let weekBefore = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let interval = period.interval(now: now, calendar: calendar)
        let inPeriod = counted.filter { interval.start <= $0.session.startedAt && $0.session.startedAt < interval.end }
        let barStart = bucketStart(of: interval.start, bucket: period.loadBucket, calendar: calendar)
        let inBars = counted.filter { barStart <= $0.session.startedAt && $0.session.startedAt < interval.end }

        return LoadStats(
            today: today,
            acuteWeekBefore: ratios.result(on: weekBefore)?.acute,
            ratioPoints: ratioPoints(ratios: ratios, interval: interval, bucket: period.chartBucket, calendar: calendar),
            daysUntilRatio: daysUntilRatio(historyStart: historyStart, now: now, calendar: calendar),
            verdict: verdict(ratios: ratios, deloadUntil: deloadUntil, now: now, calendar: calendar),
            bars: bars(of: inBars, interval: interval, bucket: period.loadBucket, calendar: calendar),
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
        switch ACWRZone(ratio: ratio) {
        case .undertraining:
            return .low
        case .elevated, .risk:
            return .elevated(days: streak(of: ratios, endingOn: now, calendar: calendar) { $0 != .optimal && $0 != .undertraining })
        case .optimal:
            break
        }
        let weeks = streak(of: ratios, endingOn: now, calendar: calendar) { $0 == .optimal } / 7
        return weeks >= 1 ? .optimal(weeks: weeks) : .steady
    }

    /// Le nombre de jours d'affilée, jusqu'à aujourd'hui, dont le ratio vérifie `matches` ; la série s'arrête au premier jour
    /// sans ratio.
    private static func streak(of ratios: DailyRatios, endingOn now: Date, calendar: Calendar, matches: (ACWRZone) -> Bool) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: now)
        while let ratio = ratios.result(on: day)?.ratio, matches(ACWRZone(ratio: ratio)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    // MARK: - Barres et totaux

    /// Le début du jour, ou du lundi de la semaine, qui contient `date`.
    private static func bucketStart(of date: Date, bucket: StatsBucket, calendar: Calendar) -> Date {
        bucket == .day ? calendar.startOfDay(for: date) : WeekSchedule.weekStart(of: date, calendar: calendar)
    }

    /// Une barre par grain sur toute la période, les grains vides compris. Chaque barre couvre son grain entier, du lundi au
    /// dimanche pour une semaine : la première, quand la période commence en milieu de semaine, compte donc aussi les séances
    /// d'avant la période, pour ne pas afficher un creux qui n'existe pas. Les totaux, eux, restent sur la période seule.
    private static func bars(of sessions: [CountedSession], interval: DateInterval, bucket: StatsBucket, calendar: Calendar) -> [LoadBar] {
        func start(of date: Date) -> Date { bucketStart(of: date, bucket: bucket, calendar: calendar) }
        var bars: [Date: LoadBar] = [:]
        var cursor = start(of: interval.start)
        let step = bucket == .day ? 1 : 7
        while cursor < interval.end {
            bars[cursor] = LoadBar(start: cursor, strength: 0, run: 0, ride: 0)
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = next
        }
        for counted in sessions {
            guard let load = counted.load?.load else { continue }
            let key = start(of: counted.session.startedAt)
            switch counted.session.kind {
            case .strength: bars[key]?.strength += load
            case .run: bars[key]?.run += load
            case .ride: bars[key]?.ride += load
            }
        }
        return bars.values.sorted { $0.start < $1.start }
    }

    /// Le nombre de séances, le tonnage et les distances viennent de toutes les séances comptées, même sans durée ; les minutes,
    /// et la part de musculation de la charge, des seules séances dont la durée est connue.
    private static func totals(of sessions: [CountedSession]) -> LoadTotals {
        let loads = sessions.compactMap { counted in counted.load.map { (kind: counted.session.kind, load: $0) } }
        let totalLoad = loads.reduce(0) { $0 + $1.load.load }
        func load(_ kind: SessionKind) -> Double { loads.filter { $0.kind == kind }.reduce(0) { $0 + $1.load.load } }
        let strengthLoad = load(.strength)
        func distance(_ kind: SessionKind) -> Double {
            sessions.filter { $0.session.kind == kind }.reduce(0) { $0 + ($1.session.distanceMeters ?? 0) }
        }
        return LoadTotals(
            tonnageKg: sessions.filter { $0.session.kind == .strength }.reduce(0) { $0 + $1.session.tonnageKg },
            runMeters: distance(.run),
            rideMeters: distance(.ride),
            minutes: loads.reduce(0) { $0 + $1.load.minutes },
            sessions: sessions.count,
            strengthShare: totalLoad > 0 ? strengthLoad / totalLoad : nil,
            strengthLoad: strengthLoad, runLoad: load(.run), rideLoad: load(.ride))
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

/// Une séance comptée (terminée ou abandonnée) et sa charge, `nil` quand sa durée est inconnue.
private struct CountedSession {
    let session: WorkoutSession
    let load: LoadSession?
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
