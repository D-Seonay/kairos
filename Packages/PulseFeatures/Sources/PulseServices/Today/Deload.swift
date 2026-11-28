import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Où en est la semaine de décharge (spec M6 §10).
public enum DeloadStatus: Sendable, Equatable {
    case none
    /// Acceptée à `since` : les séances lancées sont allégées jusqu'au dimanche.
    case active(since: Date, until: Date)
    /// Refusée : les séances lancées portent la décharge refusée jusqu'au dimanche.
    case declined(until: Date)
}

/// La proposition d'une semaine de décharge : le ratio du jour, qui dépasse le seuil depuis deux jours.
public struct DeloadOffer: Sendable, Equatable {
    public var ratio: Double

    public init(ratio: Double) {
        self.ratio = ratio
    }
}

/// La semaine de décharge (spec M6 §10) : proposée quand l'ACWR reste ≥ 1,5 deux jours de suite sur une vraie base
/// d'entraînement, acceptée ou refusée jusqu'au dimanche suivant.
public enum Deload {
    public static let ratioThreshold = 1.5

    /// La fin (exclue) de la fenêtre d'une décision prise à `decision` : le lendemain du dimanche suivant. Un dimanche, c'est le
    /// dimanche d'après.
    public static func windowEnd(from decision: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: decision)
        let toSunday = Weekday.sunday.index - Weekday(date: day, calendar: calendar).index
        let days = (toSunday == 0 ? 7 : toSunday) + 1
        return calendar.date(byAdding: .day, value: days, to: day) ?? day
    }

    /// La décision la plus récente l'emporte, tant que sa fenêtre court.
    public static func status(profile: UserProfile?, now: Date, calendar: Calendar) -> DeloadStatus {
        let accepted = profile?.deloadWeekStartedAt
        let declined = profile?.deloadDeclinedAt
        if let accepted, accepted >= (declined ?? .distantPast) {
            let end = windowEnd(from: accepted, calendar: calendar)
            return now >= accepted && now < end ? .active(since: accepted, until: end) : .none
        }
        if let declined {
            let end = windowEnd(from: declined, calendar: calendar)
            return now >= declined && now < end ? .declined(until: end) : .none
        }
        return .none
    }

    /// La décharge à proposer : ratio ≥ 1,5 aujourd'hui et hier, avec 28 jours d'historique, sans décision en cours.
    /// `historyStart` vient de `TrainingLoad.historyStart`, lu sur tout l'historique. Sans trois séances dans les deux
    /// semaines d'avant la semaine aiguë, le ratio élevé est celui d'une reprise après une pause : rien n'est proposé. `extra` :
    /// la charge des autres entraînements d'Apple Santé (`HealthActivities`).
    public static func offer(sessions: [WorkoutSession], extra: [LoadSession] = [], historyStart: Date?, profile: UserProfile?,
                             now: Date, calendar: Calendar) -> DeloadOffer? {
        guard let profile, status(profile: profile, now: now, calendar: calendar) == .none,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let midnight = calendar.startOfDay(for: now)
        guard let today = TrainingLoad.acwr(sessions: sessions, extra: extra, historyStart: historyStart, now: now, calendar: calendar),
              today.ratio >= ratioThreshold,
              TrainingLoad.hasTrainingBase(sessions: sessions, extra: extra, now: now, calendar: calendar),
              let before = TrainingLoad.acwr(sessions: sessions.filter { $0.startedAt < midnight },
                                             extra: extra.filter { $0.date < midnight },
                                             historyStart: historyStart, now: yesterday, calendar: calendar),
              before.ratio >= ratioThreshold else { return nil }
        return DeloadOffer(ratio: today.ratio)
    }
}

extension DeloadStatus {
    public var isActive: Bool {
        if case .active = self { true } else { false }
    }
}
