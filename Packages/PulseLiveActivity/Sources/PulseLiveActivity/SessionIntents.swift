import AppIntents

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

/// Les intentions du package, que l'app et `PulseWidgets` déclarent dans leur propre `AppIntentsPackage`.
public struct PulseLiveActivityIntents: AppIntentsPackage {}
