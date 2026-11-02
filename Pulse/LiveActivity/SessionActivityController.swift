import ActivityKit
import Foundation
import PulseDomain
import PulseLiveActivity

/// La Live Activity de la séance au-dessus d'ActivityKit (spec M4 §15.3). Elle ne garde rien : les activités en cours sont relues
/// dans `Activity.activities`, qui survit à un arrêt forcé de l'app. Un refus du système (Live Activities désactivées) laisse la
/// séance sans activité.
struct SessionActivityController: SessionActivityControlling {
    func start(_ state: SessionActivityState) async {
        _ = try? Activity.request(attributes: Self.attributes(for: state), content: Self.content(for: state))
    }

    /// Met à jour l'activité de la séance ; sans elle (fermée par l'utilisateur ou par le système), rien.
    func update(_ state: SessionActivityState) async {
        let content = Self.content(for: state)
        for activity in Activity<PulseSessionAttributes>.activities where activity.attributes.sessionID == state.sessionID {
            await activity.update(content)
        }
    }

    /// Il n'y a qu'une séance en cours : terminer son activité, c'est les terminer toutes.
    func end() async {
        await endAll(except: nil)
    }

    func endAll(except sessionID: UUID?) async {
        for activity in Activity<PulseSessionAttributes>.activities where activity.attributes.sessionID != sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func attributes(for state: SessionActivityState) -> PulseSessionAttributes {
        PulseSessionAttributes(sessionID: state.sessionID)
    }

    static func contentState(for state: SessionActivityState) -> PulseSessionAttributes.ContentState {
        PulseSessionAttributes.ContentState(title: state.title, startedAt: state.startedAt, restStartedAt: state.restStartedAt,
                                            restEndsAt: state.restEndsAt, nextSet: state.nextSet)
    }

    private static func content(for state: SessionActivityState) -> ActivityContent<PulseSessionAttributes.ContentState> {
        ActivityContent(state: contentState(for: state), staleDate: nil)
    }
}
