import Foundation
import PulseDomain

/// Les doublons d'une course Pulse que la montre a enregistrée aussi (spec V2a §5.3).
public enum RunDuplicates {
    /// Part de la durée de la plus courte des deux courses qu'un chevauchement doit couvrir pour faire un doublon.
    public static let minimumOverlap = 0.5

    /// Retire les courses `appleHealth` qui chevauchent une course `pulse` d'au moins 50 % de la plus courte, et remplit en
    /// mémoire la FC et le RPE estimé manquants de la course Pulse avec ceux du premier doublon. Le résultat garde l'ordre reçu.
    public static func resolve(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        let pulseRuns = sessions.filter(isPulseRun)
        guard !pulseRuns.isEmpty else { return sessions }
        let watchRuns = sessions.filter { $0.source == .appleHealth && $0.kind == .run }.sorted { $0.startedAt < $1.startedAt }
        var hidden = Set<UUID>()
        var borrowed: [UUID: WorkoutSession] = [:]
        for pulse in pulseRuns {
            for watch in watchRuns where overlaps(pulse, watch) {
                hidden.insert(watch.id)
                if borrowed[pulse.id] == nil { borrowed[pulse.id] = watch }
            }
        }
        return sessions.filter { !hidden.contains($0.id) }.map { session in
            guard let duplicate = borrowed[session.id] else { return session }
            var filled = session
            filled.averageHeartRate = filled.averageHeartRate ?? duplicate.averageHeartRate
            filled.estimatedRPE = filled.estimatedRPE ?? duplicate.estimatedRPE
            return filled
        }
    }

    static func isPulseRun(_ session: WorkoutSession) -> Bool {
        session.source == .pulse && session.kind == .run
    }

    /// La fin d'une course : `endedAt`, ou à défaut le début plus la durée ; sans l'un ni l'autre, le début (durée nulle).
    static func end(of session: WorkoutSession) -> Date {
        if let endedAt = session.endedAt { return endedAt }
        return session.startedAt.addingTimeInterval((session.durationMinutes ?? 0) * 60)
    }

    private static func overlaps(_ lhs: WorkoutSession, _ rhs: WorkoutSession) -> Bool {
        let shortest = min(end(of: lhs).timeIntervalSince(lhs.startedAt), end(of: rhs).timeIntervalSince(rhs.startedAt))
        guard shortest > 0 else { return false }
        let common = min(end(of: lhs), end(of: rhs)).timeIntervalSince(max(lhs.startedAt, rhs.startedAt))
        return common > 0 && common >= shortest * minimumOverlap
    }
}
