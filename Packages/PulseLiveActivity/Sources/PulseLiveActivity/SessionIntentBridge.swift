import Foundation

/// Le passage des boutons de la Live Activity vers le service de séance de l'app. Les intentions s'exécutent dans le processus de
/// l'app, qui pose `handler` au lancement ; sans `handler`, un bouton ne fait rien.
public enum SessionIntentBridge {
    @MainActor public static var handler: (@Sendable (RestControl) async -> Void)?
    /// « Valider » : reçoit la série que l'activité affichait.
    @MainActor public static var validateHandler: (@Sendable (UUID) async -> Void)?

    public static func handle(_ control: RestControl) async {
        guard let handler = await handler else { return }
        await handler(control)
    }

    public static func validate(set setID: UUID) async {
        guard let validateHandler = await validateHandler else { return }
        await validateHandler(setID)
    }
}
