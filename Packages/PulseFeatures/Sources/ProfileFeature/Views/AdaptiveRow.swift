import SwiftUI

/// Une rangée de côté à côté qui passe en colonne aux tailles d'accessibilité, pour que ni le titre ni la valeur ne soient coupés.
/// Le contenu reçoit `isLarge` : il place son `Spacer` de la rangée seulement quand elle n'est pas en colonne.
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder let content: (_ isLarge: Bool) -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: spacing))
        layout { content(isLarge) }
    }
}
