import PulseDesignSystem
import PulseDomain
import SwiftUI

/// L'écran qui précède la demande d'écriture dans Apple Santé, la première fois qu'une séance s'enregistre (spec M4 §19.5,
/// spec M3 §7.2 : l'écriture se demande au premier besoin). « Continuer » ouvre la demande système ; fermer la feuille revient
/// au récap sans rien enregistrer.
struct HealthWriteExplanation: View {
    let onContinue: () -> Void
    @Environment(\.pulseTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color(PulsePalette.accent(for: theme).accent))
                    .accessibilityHidden(true)
                Text(String(localized: "Tes séances dans Apple Santé", bundle: .module))
                    .font(PulseFont.title(.title2))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: """
                    Pulse y écrit chaque séance terminée : un entraînement de musculation avec son début, sa fin et l'énergie \
                    estimée d'après ton poids. Les séances importées de Hevy et les séances abandonnées n'y vont pas.
                    """, bundle: .module))
                    .foregroundStyle(PulsePalette.text2)
                Text(String(localized: """
                    Si Hevy écrit aussi dans Apple Santé, coupe-le dans Hevy pour éviter les doublons. Tu peux changer d'avis \
                    dans Réglages › Santé › Pulse.
                    """, bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.muted)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // « Continuer » reste épinglé : à grande taille de texte, seul le texte défile et le bouton ne sort jamais de l'écran.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(String(localized: "Continuer", bundle: .module), action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier(LiveSessionIdentifiers.recapHealthContinue)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(PulsePalette.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pulseScreenBackground()
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
#Preview("Explication Apple Santé") {
    Color.black.sheet(isPresented: .constant(true)) {
        HealthWriteExplanation {}
    }
}

#Preview("Explication Apple Santé, accessibilité XL") {
    Color.black.sheet(isPresented: .constant(true)) {
        HealthWriteExplanation {}
            .dynamicTypeSize(.accessibility3)
    }
}
#endif
