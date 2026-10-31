import Foundation
import PulseHealth

/// Les dépendances externes de l'app, assemblées une fois au lancement.
struct AppDependencies: Sendable {
    let health: any HealthReading
    let calendar: Calendar

    /// Apple Santé réel quand l'appareil le permet, sinon une doublure vide (l'écran reste utilisable).
    static func live() -> AppDependencies {
        let health: any HealthReading = HealthKitReader.isAvailable ? HealthKitReader() : StubHealthReader()
        return AppDependencies(health: health, calendar: .current)
    }

    static func preview() -> AppDependencies {
        AppDependencies(health: StubHealthReader(), calendar: .current)
    }
}
