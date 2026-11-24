import AppIntents

/// Un bouton de la Live Activity de course : Pause ou Reprendre.
public enum RunControl: String, Sendable {
    case pause
    case resume
}

/// Le passage des boutons de la Live Activity de course vers le service de course de l'app. Les intentions s'exécutent dans le
/// processus de l'app, qui pose `handler` au lancement ; sans `handler`, un bouton ne fait rien.
public enum RunIntentBridge {
    @MainActor public static var handler: (@Sendable (RunControl) async -> Void)?

    public static func handle(_ control: RunControl) async {
        guard let handler = await handler else { return }
        await handler(control)
    }
}

/// « Pause » : met la course en cours en pause.
public struct RunPauseIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Mettre la course en pause"
    public static let isDiscoverable = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await RunIntentBridge.handle(.pause)
        return .result()
    }
}

/// « Reprendre » : relance la course en pause.
public struct RunResumeIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Reprendre la course"
    public static let isDiscoverable = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await RunIntentBridge.handle(.resume)
        return .result()
    }
}
