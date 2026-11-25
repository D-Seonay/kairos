import Foundation
import PulseDomain

/// L'ambiance choisie dans les réglages (Ivoire ou Acier), dans les préférences du groupe d'apps que l'app et l'extension
/// partagent : l'app l'écrit, les widgets la lisent à chaque chronologie. À part de l'instantané du jour, elle vaut même avant le
/// premier score. Ivoire tant que rien n'est écrit, comme l'app sans profil.
public struct WidgetThemeStore: Sendable {
    public static let key = "widget.theme"

    private let suiteName: String

    /// `suiteName` : le groupe d'apps de Pulse, ou une suite à part dans les tests.
    public init(suiteName: String = WidgetSnapshotFile.appGroupIdentifier) {
        self.suiteName = suiteName
    }

    /// Les préférences du groupe d'apps.
    public static func appGroup() -> WidgetThemeStore {
        WidgetThemeStore()
    }

    /// L'ambiance partagée ; Ivoire sans valeur écrite ou pour une valeur inconnue.
    public func read() -> Theme {
        defaults?.string(forKey: Self.key).flatMap(Theme.init(rawValue:)) ?? .amber
    }

    /// Rend `false` sans rien écrire quand l'ambiance partagée est déjà celle-ci : les widgets n'ont pas à se recharger.
    @discardableResult
    public func write(_ theme: Theme) -> Bool {
        guard let defaults, defaults.string(forKey: Self.key) != theme.rawValue else { return false }
        defaults.set(theme.rawValue, forKey: Self.key)
        return true
    }

    /// Revient à Ivoire (suppression totale des données).
    public func clear() {
        defaults?.removeObject(forKey: Self.key)
    }

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
