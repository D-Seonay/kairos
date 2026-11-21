import SwiftUI

/// La feuille de suppression totale de « Mes données » : elle garde son modèle d'une mise à jour de l'écran à l'autre, pour qu'un
/// rafraîchissement pendant la suppression ne relance pas le bouton ni n'efface le message d'échec.
struct EraseSheet: View {
    @State private var model: DataDebugModel
    private let onErased: () async -> Void

    /// `onErased` part une fois tout supprimé et la feuille fermée. Seuls les échecs de la suppression s'y affichent.
    init(dependencies: AppDependencies, onErased: @escaping () async -> Void) {
        _model = State(initialValue: DataDebugModel(dependencies: dependencies, showsStoreError: false))
        self.onErased = onErased
    }

    var body: some View {
        EraseConfirmationView(model: model, onErased: onErased)
    }
}
