import ActivityKit
import Foundation
import PulseDomain
import PulseLiveActivity

/// La Live Activity de la course au-dessus d'ActivityKit. Elle ne garde rien : les activités en cours sont relues dans
/// `Activity.activities`, qui survit à un arrêt forcé de l'app. Un refus du système (Live Activities désactivées) laisse la course
/// sans activité.
struct RunActivityController: RunActivityControlling {
    func start(_ state: RunActivityState) async {
        _ = try? Activity.request(attributes: Self.attributes(for: state), content: Self.content(for: state))
    }

    /// Met à jour l'activité de la course ; sans elle (fermée par l'utilisateur ou par le système), rien.
    func update(_ state: RunActivityState) async {
        let content = Self.content(for: state)
        for activity in Activity<PulseRunAttributes>.activities where activity.attributes.sessionID == state.sessionID {
            await activity.update(content)
        }
    }

    /// Il n'y a qu'une course en cours : terminer son activité, c'est les terminer toutes.
    func end() async {
        await endAll()
    }

    func endAll() async {
        for activity in Activity<PulseRunAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func attributes(for state: RunActivityState) -> PulseRunAttributes {
        PulseRunAttributes(sessionID: state.sessionID)
    }

    static func contentState(for state: RunActivityState) -> PulseRunAttributes.ContentState {
        PulseRunAttributes.ContentState(
            title: state.title, timerStart: state.timerStart, frozenElapsedSeconds: state.frozenElapsedSeconds,
            distanceMeters: state.distanceMeters, averagePaceSecondsPerKm: state.averagePaceSecondsPerKm, isPaused: state.isPaused)
    }

    private static func content(for state: RunActivityState) -> ActivityContent<PulseRunAttributes.ContentState> {
        ActivityContent(state: contentState(for: state), staleDate: nil)
    }
}
