import PulseDesignSystem
import SwiftUI

/// Le cache des photos de corps : une trame argentique opaque sur tout l'écran et un cadenas. Verrouillé, il dit « Photos de
/// corps verrouillées » et propose « Déverrouiller » ; quand l'app n'est simplement plus active, il ne montre que la trame, si bien
/// que l'aperçu du sélecteur d'apps ne montre jamais une photo.
struct PrivacyCover: View {
    /// `nil` : pas de bouton (scène inactive, ou écran poussé qui sera fermé).
    var onUnlock: (() -> Void)?
    var isLocked = true
    var isAuthenticating = false

    var body: some View {
        ZStack {
            PulsePalette.page
            HalftoneField(spacing: 9) { point in
                0.18 + 0.55 * Halftone.glow(at: point, center: CGPoint(x: 0.5, y: 0.32), spread: 0.42)
            }
            if isLocked {
                VStack(spacing: 16) {
                    IconChip(systemName: "lock.fill", tone: .inverted, size: 56)
                    Text(PhotoText.lockedTitle)
                        .font(PulseFont.title(.title3, weight: .semibold))
                        .foregroundStyle(PulsePalette.text)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let onUnlock {
                        Button(PhotoText.unlock, action: onUnlock)
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isAuthenticating)
                    }
                }
                .padding(PulseMetrics.spacing * 1.5)
                .background(PulsePalette.page.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny * 2, style: .continuous))
                .padding(PulseMetrics.spacing)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
    }
}

private struct BodyPhotoPrivacy: ViewModifier {
    let model: BodyPhotosModel
    /// Seul l'écran principal propose « Déverrouiller » ; les autres se ferment au reverrouillage.
    let offersUnlock: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            // Sous le cache, rien n'est lu par VoiceOver.
            .accessibilityHidden(model.showsCover)
            .overlay {
                if model.showsCover {
                    PrivacyCover(onUnlock: unlockAction, isLocked: model.lockState == .locked,
                                 isAuthenticating: model.isAuthenticating)
                }
            }
            // Chaque couche (écran, feuille, plein écran) relaie la phase : le modèle ignore les doublons.
            .onChange(of: scenePhase, initial: true) { _, phase in model.scenePhaseChanged(phase) }
    }

    private var unlockAction: (() -> Void)? {
        guard offersUnlock, !model.isCovered else { return nil }
        return { Task { await model.unlock() } }
    }
}

extension View {
    /// Pose le cache des photos de corps sur cet écran (ou cette feuille) quand la scène n'est plus active ou que la section est
    /// verrouillée, et relaie la phase de la scène au modèle. À poser sur chaque écran et chaque présentation de la section.
    func bodyPhotoPrivacy(_ model: BodyPhotosModel, offersUnlock: Bool = false) -> some View {
        modifier(BodyPhotoPrivacy(model: model, offersUnlock: offersUnlock))
    }
}

#if DEBUG
#Preview("Cache, verrouillé") {
    PrivacyCover(onUnlock: {})
}

#Preview("Cache, verrouillé, accessibilité 3") {
    PrivacyCover(onUnlock: {})
        .dynamicTypeSize(.accessibility3)
}

#Preview("Cache, app inactive") {
    PrivacyCover(isLocked: false)
}
#endif
