import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La charge d'entraînement tirée des séances enregistrées : de quoi nourrir le ratio aigu / chronique.
public enum TrainingLoad {
    /// Le RPE d'une séance sans effort noté ni estimé.
    static let defaultRPE = 6.0
    /// Le vélo pèse moins sur le corps que sa durée ne le laisserait croire : son RPE compté ne dépasse pas ce plafond.
    static let rideRPECap = 5.0

    /// Le début de l'historique d'entraînement : la fin de l'onboarding ou la plus ancienne séance enregistrée, la plus
    /// ancienne des deux. `sessions` est tout l'historique, jamais une tranche : l'accueil, les Stats, le récap et les widgets
    /// partent ainsi du même jour et montrent le même ratio. Une course ou un vélo importé d'Apple Santé ne fait pas reculer ce
    /// début : ces sorties datent d'avant Pulse, et la charge chronique d'un nouvel utilisateur ne tiendrait que d'elles (un
    /// import Hevy, lui, apporte les séances de musculation et compte).
    public static func historyStart(sessions: [WorkoutSession], onboardingCompletedAt: Date?) -> Date? {
        let oldestRecorded = sessions.lazy.filter { $0.source != .appleHealth }.map(\.startedAt).min()
        return [onboardingCompletedAt, oldestRecorded].compactMap { $0 }.min()
    }

    /// Les séances terminées et abandonnées comptent (spec M4 §14.6), jamais une séance encore en cours. `historyStart` vient
    /// de `historyStart(sessions:onboardingCompletedAt:)`, lu sur tout l'historique ; `sessions` peut n'être que les 28
    /// derniers jours. Sous 28 jours d'historique, sans début d'historique ou sans charge, il n'y a pas de ratio.
    public static func acwr(sessions: [WorkoutSession], historyStart: Date?, now: Date, calendar: Calendar) -> ACWRResult? {
        guard let historyStart else { return nil }
        return LoadCalculator(calendar: calendar).acwr(sessions: counted(sessions), asOf: now, historyStart: historyStart)
    }

    /// Vrai si les trois semaines d'avant la semaine aiguë portent assez de séances pour qu'un ratio élevé dise une surcharge
    /// (`LoadCalculator.hasTrainingBase`) : sans cette base, c'est une reprise après une pause.
    public static func hasTrainingBase(sessions: [WorkoutSession], now: Date, calendar: Calendar) -> Bool {
        LoadCalculator(calendar: calendar).hasTrainingBase(sessions: counted(sessions), asOf: now)
    }

    /// Les séances qui comptent dans la charge, avec leur charge.
    private static func counted(_ sessions: [WorkoutSession]) -> [LoadSession] {
        sessions.filter { $0.status == .completed || $0.status == .abandoned }.compactMap(loadSession)
    }

    static func loadSession(_ session: WorkoutSession) -> LoadSession? {
        guard let minutes = minutes(of: session), minutes > 0 else { return nil }
        let rpe = session.overallRPE ?? session.estimatedRPE ?? defaultRPE
        return LoadSession(date: session.startedAt, minutes: minutes, rpe: session.kind == .ride ? min(rpe, rideRPECap) : rpe)
    }

    private static func minutes(of session: WorkoutSession) -> Double? {
        if let duration = session.durationMinutes { return duration }
        return session.endedAt.map { $0.timeIntervalSince(session.startedAt) / 60 }
    }
}
