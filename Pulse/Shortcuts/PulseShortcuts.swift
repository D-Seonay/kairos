import AppIntents

/// Les raccourcis de Pulse, proposés par Siri, Spotlight et l'app Raccourcis. Les phrases sont en français (traduites dans
/// `AppShortcuts.xcstrings`, la langue de développement du projet étant l'anglais) et portent toutes le nom de l'app.
struct PulseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecoveryScoreIntent(),
            phrases: [
                "Quel est mon score de récupération dans \(.applicationName)",
                "Mon score de récupération \(.applicationName)",
                "Comment je récupère selon \(.applicationName)"
            ],
            shortTitle: "Score de récupération",
            systemImageName: "heart")
        AppShortcut(
            intent: StartTodaySessionIntent(),
            phrases: [
                "Démarrer la séance du jour dans \(.applicationName)",
                "Lance ma séance \(.applicationName)",
                "Démarrer ma séance avec \(.applicationName)"
            ],
            shortTitle: "Séance du jour",
            systemImageName: "dumbbell")
        AppShortcut(
            intent: TakeSupplementIntent(),
            phrases: [
                "J'ai pris ma \(\.$supplement) dans \(.applicationName)",
                "J'ai pris mon \(\.$supplement) dans \(.applicationName)",
                "J'ai pris \(\.$supplement) avec \(.applicationName)",
                "Cocher un complément dans \(.applicationName)"
            ],
            shortTitle: "Complément pris",
            systemImageName: "pills")
        AppShortcut(
            intent: StartRunIntent(),
            phrases: [
                "Lancer une course avec \(.applicationName)",
                "Lance une course \(.applicationName)",
                "Courir avec \(.applicationName)"
            ],
            shortTitle: "Lancer une course",
            systemImageName: "figure.run")
    }
}
