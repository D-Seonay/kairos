import Foundation

/// Les données de départ qu'un test d'interface demande au lancement (`-PulseSeed <nom>`).
public enum LaunchSeed: String, Sendable {
    /// Un profil terminé avec le modèle `ppl-3` adopté et actif.
    case onboardedPPL
}

/// La réponse de la doublure de Face ID des tests d'interface (`-PulseOwnerAuthentication <nom>`). Elle ne remplace le vrai
/// Face ID que dans les modes des tests d'interface (`-PulseStore`), en Debug.
public enum OwnerAuthenticationScenario: String, Sendable {
    /// L'iPhone a un code et l'authentification réussit.
    case succeeds
    /// L'iPhone a un code et l'authentification échoue (refus, annulation).
    case fails
    /// L'iPhone n'a pas de code : ni verrou ni chiffrement.
    case noPasscode
}

/// Options de lancement des builds Debug, lues dans les arguments du processus (tests d'interface, aperçus).
public struct LaunchOptions: Sendable, Equatable {
    public var storeInMemory: Bool
    /// Un magasin sur disque qui survit à un arrêt forcé de l'app, pour tester la reprise.
    public var storeOnDisk: Bool
    /// Le dossier du magasin sur disque est effacé au lancement.
    public var resetsStore: Bool
    public var seed: LaunchSeed?
    public var healthScenario: HealthScenario?
    public var fixedNow: Date?
    /// La réponse de la doublure de Face ID, dans les modes des tests d'interface seulement.
    public var ownerAuthentication: OwnerAuthenticationScenario

    public init(storeInMemory: Bool = false, storeOnDisk: Bool = false, resetsStore: Bool = false, seed: LaunchSeed? = nil,
                healthScenario: HealthScenario? = nil, fixedNow: Date? = nil,
                ownerAuthentication: OwnerAuthenticationScenario = .succeeds) {
        self.storeInMemory = storeInMemory
        self.storeOnDisk = storeOnDisk
        self.resetsStore = resetsStore
        self.seed = seed
        self.healthScenario = healthScenario
        self.fixedNow = fixedNow
        self.ownerAuthentication = ownerAuthentication
    }

    /// `-PulseStore inMemory|disk`, `-PulseResetStore YES`, `-PulseSeed onboardedPPL`, `-PulseHealthScenario <nom>`,
    /// `-PulseNow <ISO 8601>`, `-PulseOwnerAuthentication succeeds|fails|noPasscode`. Une valeur inconnue est ignorée.
    public static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        for (index, argument) in arguments.enumerated() {
            guard index + 1 < arguments.count else { break }
            let value = arguments[index + 1]
            switch argument {
            case "-PulseStore":
                options.storeInMemory = options.storeInMemory || value == "inMemory"
                options.storeOnDisk = options.storeOnDisk || value == "disk"
            case "-PulseResetStore": options.resetsStore = options.resetsStore || value == "YES"
            case "-PulseSeed": options.seed = LaunchSeed(rawValue: value) ?? options.seed
            case "-PulseHealthScenario": options.healthScenario = HealthScenario(rawValue: value) ?? options.healthScenario
            case "-PulseNow": options.fixedNow = parseDate(value) ?? options.fixedNow
            case "-PulseOwnerAuthentication":
                options.ownerAuthentication = OwnerAuthenticationScenario(rawValue: value) ?? options.ownerAuthentication
            default: break
            }
        }
        return options
    }

    private static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: text) ?? fractional.date(from: text)
    }
}
