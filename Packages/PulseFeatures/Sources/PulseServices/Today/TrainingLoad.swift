import Foundation
import PulseDomain
import PulseRecoveryEngine

/// La charge d'entraînement tirée des séances enregistrées : de quoi nourrir le ratio aigu / chronique.
public enum TrainingLoad {
    /// Le RPE d'une séance sans effort noté ni estimé.
    static let defaultRPE = 6.0
    /// Le vélo pèse moins sur le corps que sa durée ne le laisserait croire : son RPE compté ne dépasse pas ce plafond.
    static let rideRPECap = 5.0

    /// Seules les séances terminées comptent. L'historique commence à la fin de l'onboarding ou à la plus ancienne séance lue,
    /// la plus ancienne des deux ; sous 28 jours d'historique, ou sans charge, il n'y a pas de ratio.
    public static func acwr(sessions: [WorkoutSession], onboardingCompletedAt: Date?, now: Date, calendar: Calendar) -> ACWRResult? {
        let historyStart = ([onboardingCompletedAt] + sessions.map(\.startedAt)).compactMap { $0 }.min() ?? now
        let counted = sessions.filter { $0.status == .completed }.compactMap(loadSession)
        return LoadCalculator(calendar: calendar).acwr(sessions: counted, asOf: now, historyStart: historyStart)
    }

    private static func loadSession(_ session: WorkoutSession) -> LoadSession? {
        guard let minutes = minutes(of: session), minutes > 0 else { return nil }
        let rpe = session.overallRPE ?? session.estimatedRPE ?? defaultRPE
        return LoadSession(date: session.startedAt, minutes: minutes, rpe: session.kind == .ride ? min(rpe, rideRPECap) : rpe)
    }

    private static func minutes(of session: WorkoutSession) -> Double? {
        if let duration = session.durationMinutes { return duration }
        return session.endedAt.map { $0.timeIntervalSince(session.startedAt) / 60 }
    }
}
