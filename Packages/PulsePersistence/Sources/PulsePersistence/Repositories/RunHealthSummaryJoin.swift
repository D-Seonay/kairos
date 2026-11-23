import Foundation
import PulseDomain
import SwiftData

/// La FC moyenne et le RPE estimé des courses Pulse : écrits dans le résumé local, réinjectés à la lecture (frontière M8).
enum RunHealthSummaryJoin {
    /// Seules les courses enregistrées par Pulse passent par le résumé.
    static func isPulseRun(_ session: WorkoutSession) -> Bool {
        session.source == .pulse && session.kind == .run
    }

    /// Recolle le résumé local sur chaque course Pulse ; une course sans résumé (enregistrée sur un autre appareil) reste
    /// sans FC ni RPE estimé, les autres séances restent telles quelles.
    static func fill(_ sessions: [WorkoutSession], in context: ModelContext) throws -> [WorkoutSession] {
        let ids = sessions.filter(isPulseRun).map(\.id)
        guard !ids.isEmpty else { return sessions }
        let summaries = try context.fetch(FetchDescriptor<StoredRunHealthSummary>(predicate: #Predicate { ids.contains($0.sessionID) }))
        let byID = Dictionary(summaries.map { ($0.sessionID, $0) }, uniquingKeysWith: { first, _ in first })
        return sessions.map { session in
            guard isPulseRun(session), let summary = byID[session.id] else { return session }
            var filled = session
            filled.averageHeartRate = summary.averageHeartRate
            filled.estimatedRPE = summary.estimatedRPE
            return filled
        }
    }

    /// Écrit le résumé d'une course Pulse (une ligne par séance) et renvoie la séance sans ses deux valeurs, prête pour le
    /// magasin synchronisé. Toute autre séance perd un éventuel résumé (changement de source ou de type) et revient intacte.
    static func store(_ session: WorkoutSession, in context: ModelContext) throws -> WorkoutSession {
        let id = session.id
        let existing = try context.first(StoredRunHealthSummary.self, where: #Predicate { $0.sessionID == id })
        guard isPulseRun(session) else {
            if let existing { context.delete(existing) }
            return session
        }
        if session.averageHeartRate == nil && session.estimatedRPE == nil {
            if let existing { context.delete(existing) }   // une ligne vide ne sert à rien
        } else if let existing {
            existing.averageHeartRate = session.averageHeartRate
            existing.estimatedRPE = session.estimatedRPE
        } else {
            context.insert(StoredRunHealthSummary(sessionID: id, averageHeartRate: session.averageHeartRate,
                                                  estimatedRPE: session.estimatedRPE))
        }
        var synced = session
        synced.averageHeartRate = nil
        synced.estimatedRPE = nil
        return synced
    }

    /// Supprime le résumé local de la séance, s'il existe.
    static func remove(sessionID id: UUID, in context: ModelContext) throws {
        try context.delete(model: StoredRunHealthSummary.self, where: #Predicate { $0.sessionID == id })
    }
}
