import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Écran 1, `bienvenue` : le logo, la promesse, trois bénéfices et « Commencer ».
struct WelcomeView: View {
    let model: OnboardingModel
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            brand
            ObsidianCard {
                VStack(alignment: .leading, spacing: 14) {
                    OnboardingInfoRow(
                        systemImage: "heart.fill",
                        title: String(localized: "Un score de récupération chaque matin", bundle: .module),
                        detail: String(
                            localized: "Variabilité cardiaque, fréquence au repos et sommeil, comparés à ta propre moyenne.",
                            bundle: .module))
                    OnboardingInfoRow(
                        systemImage: "dumbbell.fill",
                        title: String(localized: "Des séances qui s'adaptent", bundle: .module),
                        detail: String(
                            localized: "Volume, intensité et repos ajustés avant que tu touches une barre.", bundle: .module))
                    OnboardingInfoRow(
                        systemImage: "figure.run",
                        title: String(localized: "Muscu et course réconciliées", bundle: .module),
                        detail: String(
                            localized: "Le planificateur espace les jambes lourdes et le fractionné.", bundle: .module))
                }
            }
        } footer: {
            OnboardingButton(
                title: String(localized: "Commencer", bundle: .module), identifier: OnboardingIdentifiers.welcomeStart,
                style: PrimaryButtonStyle()
            ) { await model.begin() }
            Text(String(localized: "Pulse n'est pas un dispositif médical.", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var brand: some View {
        let palette = PulsePalette.accent(for: theme)
        return VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(palette.accentInk))
                .frame(width: 56, height: 56)
                .background(Color(palette.accent), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            Text(String(localized: "Ton corps décide de la séance du jour.", bundle: .module))
                .font(.system(.largeTitle, weight: .heavy))
                .foregroundStyle(PulsePalette.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(String(
                localized: """
                    Pulse lit ta récupération chaque matin et ajuste musculation et course pour que les deux \
                    progressent sans se nuire.
                    """,
                bundle: .module))
                .font(.body)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 8)
    }
}

#if DEBUG
#Preview {
    ZStack {
        PulsePalette.background.ignoresSafeArea()
        AuraBackground().ignoresSafeArea()
        WelcomeView(model: OnboardingPreviewSupport.model(step: .welcome))
    }
}
#endif
