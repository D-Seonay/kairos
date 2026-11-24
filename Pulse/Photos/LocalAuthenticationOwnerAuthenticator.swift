import Foundation
import LocalAuthentication
import PulseDomain

/// Face ID, Touch ID ou le code de l'iPhone, pour déverrouiller les photos de corps. Un nouveau contexte à chaque appel : une
/// authentification réussie n'en ouvre jamais une seconde.
struct LocalAuthenticationOwnerAuthenticator: DeviceOwnerAuthenticating {
    /// Faux seulement quand l'iPhone n'a pas de code. Tout autre échec (biométrie bloquée ou non configurée) laisse le verrou
    /// en place : la demande retombe alors sur le code, et la section ne s'ouvre jamais sans lui.
    func isAvailable() async -> Bool {
        var error: NSError?
        guard !LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return !Self.isPasscodeNotSet(error)
    }

    /// Une annulation ou un échec vaut un refus.
    func authenticate(reason: String) async -> Bool {
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    static func isPasscodeNotSet(_ error: NSError?) -> Bool {
        guard let error, error.domain == LAErrorDomain else { return false }
        return error.code == LAError.Code.passcodeNotSet.rawValue
    }
}
