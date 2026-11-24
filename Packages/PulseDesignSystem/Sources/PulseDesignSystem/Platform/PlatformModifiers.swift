import SwiftUI

#if os(iOS)
import AudioToolbox
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

    /// Légère, à la modification d'une valeur en séance.
    @MainActor
    public static func light() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Double, à la validation d'une série.
    @MainActor
    public static func validation() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            generator.impactOccurred()
        }
        #endif
    }

    /// Longue, à la fin du repos.
    @MainActor
    public static func restEnded() {
        #if os(iOS)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
    }

    /// Sèche et brève : un tic de compte à rebours, l'ajout d'une série.
    @MainActor
    public static func tick() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        #endif
    }

    /// Molle : une série dévalidée ou supprimée, un pas en arrière.
    @MainActor
    public static func soft() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    /// Le succès du système, juste après la double vibration de la validation : la dernière série d'un exercice est faite.
    @MainActor
    public static func success() {
        #if os(iOS)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    /// Une montée de trois coups de plus en plus forts puis le succès : toute la séance est faite.
    @MainActor
    public static func celebration() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            for intensity in [0.45, 0.7, 1.0] {
                generator.impactOccurred(intensity: intensity)
                try? await Task.sleep(for: .milliseconds(110))
            }
            try? await Task.sleep(for: .milliseconds(80))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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

    /// Saisie d'un prénom : le type de contenu `givenName` laisse le clavier proposer le prénom de l'utilisateur.
    func pulseGivenNameField() -> some View {
        #if os(iOS)
        textContentType(.givenName)
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
