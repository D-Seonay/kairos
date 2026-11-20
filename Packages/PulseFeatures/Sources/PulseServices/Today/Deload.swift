import Foundation
import PulseDomain
import PulseRecoveryEngine

/// Où en est la semaine de décharge (spec M6 §10).
public enum DeloadStatus: Sendable, Equatable {
    case none
    /// Acceptée : les séances lancées sont allégées jusqu'au dimanche.
    case active(until: Date)
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

/// La semaine de décharge (spec M6 §10) : proposée quand l'ACWR reste ≥ 1,5 deux jours de suite, acceptée ou refusée jusqu'au
/// dimanche suivant.
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
            return now >= accepted && now < end ? .active(until: end) : .none
        }
        if let declined {
            let end = windowEnd(from: declined, calendar: calendar)
            return now >= declined && now < end ? .declined(until: end) : .none
        }
        return .none
    }

    /// La décharge à proposer : ratio ≥ 1,5 aujourd'hui et hier, avec 28 jours d'historique, sans décision en cours.
    public static func offer(sessions: [WorkoutSession], profile: UserProfile?, now: Date, calendar: Calendar) -> DeloadOffer? {
        guard let profile, status(profile: profile, now: now, calendar: calendar) == .none,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
        let onboarded = profile.onboardingCompletedAt
        guard let today = TrainingLoad.acwr(sessions: sessions, onboardingCompletedAt: onboarded, now: now, calendar: calendar),
              today.ratio >= ratioThreshold,
              let before = TrainingLoad.acwr(sessions: sessions.filter { $0.startedAt < calendar.startOfDay(for: now) },
                                             onboardingCompletedAt: onboarded, now: yesterday, calendar: calendar),
              before.ratio >= ratioThreshold else { return nil }
        return DeloadOffer(ratio: today.ratio)
    }
}

extension DeloadStatus {
    public var isActive: Bool {
        if case .active = self { true } else { false }
    }
}
