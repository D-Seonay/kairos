import ProfileFeature
import SwiftUI

/// Les écrans de la cible app que l'onglet Profil pousse, rangés à part pour garder `MainTabView` sous la longueur permise.
extension MainTabView {
    /// Les écrans de la cible app que l'onglet Profil pousse : le diagnostic Apple Santé (Paramètres), la confirmation de
    /// suppression et, en Debug seulement, l'écran « Données » (Mes données).
    var profileScreens: ProfileAppScreens {
        let dependencies = dependencies
        return ProfileAppScreens(
            healthDiagnostics: {
                AnyView(HealthDiagnosticsView(model: HealthDiagnosticsModel(dependencies: dependencies, today: dependencies.now())))
            },
            dataDebug: dataDebugScreen,
            eraseConfirmation: { onErased in AnyView(EraseSheet(dependencies: dependencies, onErased: onErased)) })
    }

    /// L'écran de debug « Données » (données d'exemple, inspection des tables) n'existe pas en Release (spec M7 §16).
    var dataDebugScreen: (() -> AnyView)? {
        #if DEBUG
        let dependencies = dependencies
        let onErased = onErased
        return { AnyView(DataDebugView(model: DataDebugModel(dependencies: dependencies), onErased: onErased)) }
        #else
        return nil
        #endif
    }
}
