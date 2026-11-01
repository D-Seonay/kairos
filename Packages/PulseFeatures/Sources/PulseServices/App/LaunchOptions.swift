import Foundation

/// Options de lancement des builds Debug, lues dans les arguments du processus (tests d'interface, aperçus).
public struct LaunchOptions: Sendable, Equatable {
    public var storeInMemory: Bool
    public var healthScenario: HealthScenario?
    public var fixedNow: Date?

    public init(storeInMemory: Bool = false, healthScenario: HealthScenario? = nil, fixedNow: Date? = nil) {
        self.storeInMemory = storeInMemory
        self.healthScenario = healthScenario
        self.fixedNow = fixedNow
    }

    /// `-PulseStore inMemory`, `-PulseHealthScenario <nom>`, `-PulseNow <ISO 8601>`. Une valeur inconnue est ignorée.
    public static func parse(_ arguments: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        for (index, argument) in arguments.enumerated() {
            guard index + 1 < arguments.count else { break }
            let value = arguments[index + 1]
            switch argument {
            case "-PulseStore": options.storeInMemory = options.storeInMemory || value == "inMemory"
            case "-PulseHealthScenario": options.healthScenario = HealthScenario(rawValue: value) ?? options.healthScenario
            case "-PulseNow": options.fixedNow = parseDate(value) ?? options.fixedNow
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
