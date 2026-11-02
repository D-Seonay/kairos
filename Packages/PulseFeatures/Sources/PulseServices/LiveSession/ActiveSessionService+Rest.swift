import Foundation
import PulseDomain

/// Le chrono de repos (spec M4 §15.1), sa notification de fin (§15.2) et la Live Activity (§15.3). Le repos tient dans sa date
/// de fin : il reste juste après une mise en veille ou une relance.
extension ActiveSessionService {
    static let warmUpRestSeconds: TimeInterval = 60
    static let restStepSeconds: TimeInterval = 30

    /// Le repos après le geste. Valider une série lance le repos de l'exercice (60 s pour un échauffement) et remplace celui
    /// en cours ; dévalider la série qui l'a lancé l'arrête ; −30 s ne remonte jamais avant maintenant.
    static func rest(after change: LiveSessionChange, before: LiveSession, session: LiveSession, now: Date) -> LiveRest? {
        let current = session.rest
        switch change {
        case let .validate(exercise, set):
            guard before.set(set, of: exercise)?.completedAt == nil, session.set(set, of: exercise)?.completedAt != nil else {
                return current
            }
            return session.restStarted(byValidating: set, of: exercise, now: now)
        case let .unvalidate(exercise, set):
            guard let current, current.exerciseID == exercise,
                  current.startedAt == before.set(set, of: exercise)?.completedAt else { return current }
            return nil
        case .restMinus30:
            guard var rest = current else { return nil }
            rest.endsAt = max(now, rest.endsAt.addingTimeInterval(-restStepSeconds))
            return rest.endsAt > now ? rest : nil
        case .restPlus30:
            guard var rest = current else { return nil }
            rest.endsAt = rest.endsAt.addingTimeInterval(restStepSeconds)
            return rest
        case .skipRest:
            return nil
        default:
            return current
        }
    }

    /// Replanifie la notification quand le repos ou la série suivante change, l'annule quand le repos s'arrête, et met à jour
    /// la Live Activity quand ce qu'elle montre change.
    func publish(from old: LiveSession, to new: LiveSession) async {
        if let rest = new.rest {
            let message = Self.restEndMessage(for: new)
            if rest != old.rest || message != Self.restEndMessage(for: old), await restNotificationsEnabled() {
                await restNotifier.scheduleRestEnd(at: rest.endsAt, message: message)
            }
        } else if old.rest != nil {
            await restNotifier.cancelRestEnd()
        }
        let state = Self.activityState(for: new)
        if state != Self.activityState(for: old) {
            await activity.update(state)
        }
    }

    /// Sans profil lisible, la notification garde sa valeur par défaut : activée.
    private func restNotificationsEnabled() async -> Bool {
        (try? await profiles.load())?.restTimerNotificationEnabled ?? true
    }

    /// « Repos terminé » ; « Développé couché à la barre, série 2 : 70 kg × 5 ».
    static func restEndMessage(for session: LiveSession) -> RestEndMessage {
        let title = String(localized: "Repos terminé", bundle: .module)
        guard let next = session.nextSetParts else { return RestEndMessage(title: title, body: session.title) }
        let body = next.values.map { String(localized: "\(next.name), série \(next.number) : \($0)", bundle: .module) }
            ?? String(localized: "\(next.name), série \(next.number)", bundle: .module)
        return RestEndMessage(title: title, body: body)
    }

    /// Le titre, les dates de la séance et du repos, et « Développé couché à la barre · série 2 · 70 kg × 5 ».
    static func activityState(for session: LiveSession) -> SessionActivityState {
        let nextSet = session.nextSetParts.map { next in
            next.values.map { String(localized: "\(next.name) · série \(next.number) · \($0)", bundle: .module) }
                ?? String(localized: "\(next.name) · série \(next.number)", bundle: .module)
        }
        return SessionActivityState(sessionID: session.id, title: session.title, startedAt: session.startedAt,
                                    restStartedAt: session.rest?.startedAt, restEndsAt: session.rest?.endsAt, nextSet: nextSet)
    }
}

extension LiveSession {
    /// Efface un repos dont la fin est passée.
    mutating func clearRest(endedBy now: Date) {
        if let rest, rest.endsAt <= now { self.rest = nil }
    }

    /// Le repos lancé par la validation de la série : aucun après la dernière série de la séance, ni tant qu'un autre exercice
    /// du même super set n'a pas fait la série de ce tour.
    fileprivate func restStarted(byValidating setID: UUID, of exerciseID: UUID, now: Date) -> LiveRest? {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let round = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }),
              nextSet != nil else { return nil }
        let partnerPending = block(containing: exerciseIndex).contains { index in
            index != exerciseIndex && round < exercises[index].sets.count && exercises[index].sets[round].completedAt == nil
        }
        guard !partnerPending else { return nil }
        let exercise = exercises[exerciseIndex]
        let seconds = exercise.sets[round].setType == .warmup
            ? ActiveSessionService.warmUpRestSeconds : TimeInterval(exercise.restSeconds)
        return LiveRest(startedAt: now, endsAt: now.addingTimeInterval(seconds), exerciseID: exerciseID)
    }

    /// L'exercice seul, ou les exercices voisins du même super set.
    private func block(containing index: Int) -> Range<Int> {
        guard let group = exercises[index].supersetGroup else { return index..<(index + 1) }
        var start = index
        while start > 0, exercises[start - 1].supersetGroup == group { start -= 1 }
        var end = index + 1
        while end < exercises.count, exercises[end].supersetGroup == group { end += 1 }
        return start..<end
    }

    /// La prochaine série, telle que la notification et la Live Activity la nomment.
    fileprivate var nextSetParts: NextSetParts? {
        guard let next = nextSet else { return nil }
        let exercise = exercises[next.exerciseIndex]
        return NextSetParts(name: exercise.name, number: next.setIndex + 1,
                            values: LiveSessionText.planned(exercise.sets[next.setIndex], of: exercise))
    }
}

/// Le nom de l'exercice, le numéro de la série dans l'exercice, et ses valeurs prévues (« 70 kg × 5 ») s'il y en a.
private struct NextSetParts {
    var name: String
    var number: Int
    var values: String?
}
