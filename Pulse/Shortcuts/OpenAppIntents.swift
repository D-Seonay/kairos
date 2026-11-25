import AppIntents
import Foundation
import PulseDomain

/// « Démarrer la séance du jour » : ouvre Pulse sur le lien `start-session`, comme le contrôle « Séance du jour » ; l'accueil
/// lance la séance adaptée du jour, ou rouvre celle en cours. Un jour sans musculation à lancer, l'accueil reste affiché.
struct StartTodaySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Démarrer la séance du jour"
    static let description = IntentDescription("Ouvre Pulse et lance la séance du jour, ajustée à ta récupération.")

    func perform() async throws -> some IntentResult & OpensIntent {
        try .result(opensIntent: OpenURLIntent(AppLink.startSession.requiredURL))
    }
}

/// « Lancer une course » : ouvre Pulse sur le départ de la course du jour, ou d'une course libre (lien `run`).
struct StartRunIntent: AppIntent {
    static let title: LocalizedStringResource = "Lancer une course"
    static let description = IntentDescription("Ouvre Pulse sur le départ de la course du jour, ou d'une course libre.")

    func perform() async throws -> some IntentResult & OpensIntent {
        try .result(opensIntent: OpenURLIntent(AppLink.run.requiredURL))
    }
}

/// « Voir pourquoi », sous le score lu par Siri : ouvre Pulse sur l'écran « Pourquoi » du score du jour (lien `why`). Sans
/// score à expliquer, l'accueil s'affiche.
struct OpenWhyIntent: AppIntent {
    static let title: LocalizedStringResource = "Voir pourquoi"
    static let description = IntentDescription("Ouvre Pulse sur l'explication du score de récupération du jour.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        try .result(opensIntent: OpenURLIntent(AppLink.why.requiredURL))
    }
}

extension AppLink {
    /// L'URL du lien ; une erreur plutôt qu'un lien vide si elle ne se construit pas.
    var requiredURL: URL {
        get throws {
            guard let url else { throw URLError(.badURL) }
            return url
        }
    }
}
