import Foundation
import PulseDomain
import Synchronization

/// Le code de l'iPhone, simulé : `available` (l'iPhone a un code) et `succeeds` (Face ID réussit) se règlent pendant le test,
/// et chaque demande d'authentification garde sa raison.
final class StubOwnerAuthentication: DeviceOwnerAuthenticating {
    private struct State {
        var available: Bool
        var succeeds: Bool
        var reasons: [String] = []
    }

    private let state: Mutex<State>

    init(available: Bool = true, succeeds: Bool = true) {
        state = Mutex(State(available: available, succeeds: succeeds))
    }

    var available: Bool {
        get { state.withLock { $0.available } }
        set { state.withLock { $0.available = newValue } }
    }

    var succeeds: Bool {
        get { state.withLock { $0.succeeds } }
        set { state.withLock { $0.succeeds = newValue } }
    }

    /// Les raisons des demandes, dans l'ordre.
    var reasons: [String] {
        state.withLock { $0.reasons }
    }

    func isAvailable() async -> Bool {
        available
    }

    func authenticate(reason: String) async -> Bool {
        state.withLock { state in
            state.reasons.append(reason)
            return state.succeeds
        }
    }
}
