import AppIntents
import Foundation

/// « −30 s » : raccourcit le repos en cours, sans le faire finir avant maintenant.
public struct RestMinus30Intent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Repos moins 30 secondes"
    public static let isDiscoverable = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await SessionIntentBridge.handle(.minus30)
        return .result()
    }
}

/// « +30 s » : allonge le repos en cours.
public struct RestPlus30Intent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Repos plus 30 secondes"
    public static let isDiscoverable = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await SessionIntentBridge.handle(.plus30)
        return .result()
    }
}

/// « Passer » : arrête le repos en cours.
public struct SkipRestIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Passer le repos"
    public static let isDiscoverable = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await SessionIntentBridge.handle(.skip)
        return .result()
    }
}

/// « Valider » : coche la série suivante affichée, avec sa proposition, et lance le repos comme dans l'app. L'identifiant de la
/// série voyage avec le bouton : une activité en retard sur la séance ne coche pas une autre série.
public struct ValidateSetIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Valider la série"
    public static let isDiscoverable = false

    @Parameter(title: "Série")
    public var setID: String

    public init() {}

    public init(setID: UUID) {
        self.setID = setID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: setID) {
            await SessionIntentBridge.validate(set: id)
        }
        return .result()
    }
}

/// Les intentions du package, que l'app et `PulseWidgets` déclarent dans leur propre `AppIntentsPackage`.
public struct PulseLiveActivityIntents: AppIntentsPackage {}
