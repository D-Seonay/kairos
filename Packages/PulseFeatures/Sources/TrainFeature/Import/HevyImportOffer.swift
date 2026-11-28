import PulseDesignSystem
import SwiftUI

/// « Tu viens d'une autre app ? » : l'offre d'importer l'historique Hevy, là où elle compte le plus (historique vide,
/// onboarding). Le contenu de la ligne ; l'action (lien de navigation, feuille) est celle de l'écran qui l'affiche.
public struct HevyImportOfferLabel: View {
    public init() {}

    public static var title: String { String(localized: "Tu viens d'une autre app ?", bundle: .module) }
    public static var detail: String {
        String(localized: "Importe ton historique Hevy : la progression part de tes charges dès la première séance.", bundle: .module)
    }

    public var body: some View {
        PulseRow(systemImage: "square.and.arrow.down", title: Self.title, detail: Self.detail)
    }
}
