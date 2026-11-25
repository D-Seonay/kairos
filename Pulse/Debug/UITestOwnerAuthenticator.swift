#if DEBUG
import Foundation
import PulseDomain
import PulseServices

/// La doublure de Face ID des tests d'interface : elle répond selon `-PulseOwnerAuthentication`, sans jamais présenter la
/// demande système. Elle n'existe qu'en Debug, et le câblage ne la branche que dans les modes des tests d'interface
/// (`Wiring.useMemoryDoubles`) : l'app réelle, et toute build Release, gardent le vrai Face ID.
struct UITestOwnerAuthenticator: DeviceOwnerAuthenticating {
    let scenario: OwnerAuthenticationScenario

    func isAvailable() async -> Bool {
        scenario != .noPasscode
    }

    func authenticate(reason: String) async -> Bool {
        scenario == .succeeds
    }
}
#endif
