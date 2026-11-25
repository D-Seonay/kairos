import PulseDesignSystem
import SwiftUI

/// Le message d'erreur d'un écran de la course (départ, course, récap), sous son contenu, dans la couleur du signal. Rien sans
/// message.
struct RunErrorLine: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(PulsePalette.signal)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    /// Ancre les boutons d'un écran de la course (« Partir », « Pause » et « Terminer », « Enregistrer » et « Supprimer ») sous
    /// le contenu qui défile, avec les mêmes marges partout. `opaque` pose le fond de l'écran derrière eux, quand le contenu ne
    /// doit pas transparaître (le champ de note du récap).
    func runActionBar(opaque: Bool = false, @ViewBuilder _ actions: () -> some View) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            actions()
                .padding(.horizontal, PulseMetrics.spacing)
                .padding(.vertical, 8)
                .background(opaque ? PulsePalette.background : Color.clear)
        }
    }
}
