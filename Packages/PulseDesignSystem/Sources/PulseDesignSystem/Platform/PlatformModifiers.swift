import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Retours haptiques. Sans effet hors iOS, pour que le package compile et se teste sur Mac.
public enum PulseHaptics {
    @MainActor
    public static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

public extension View {
    /// Clavier numérique décimal pour les champs de mesure (taille, poids).
    func pulseNumericKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Titre de navigation compact, comme les écrans d'onboarding de la maquette.
    func pulseInlineTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
