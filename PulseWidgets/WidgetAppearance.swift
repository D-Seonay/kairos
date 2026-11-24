import SwiftUI
import WidgetKit

extension View {
    /// L'app est toujours sur papier (`AppRootView` la force en clair) : sur l'écran d'accueil, un widget se compose en clair lui
    /// aussi, sinon l'apparence sombre du système le passerait au noir alors que l'app reste claire. Comme la Live Activity fixe
    /// son apparence, le widget fixe la sienne. Les familles de l'écran verrouillé gardent l'apparence du système, qui les teinte.
    func pulsePaperAppearance(for family: WidgetFamily) -> some View {
        transformEnvironment(\.colorScheme) { scheme in
            if family.isHomeScreen { scheme = .light }
        }
    }
}

private extension WidgetFamily {
    /// Les tailles de l'écran d'accueil, en couleur pleine.
    var isHomeScreen: Bool {
        switch self {
        case .systemSmall, .systemMedium, .systemLarge: true
        default: false
        }
    }
}
