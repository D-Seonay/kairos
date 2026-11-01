import PulseDesignSystem
import SwiftUI

/// Écran 2, `sante` : ce que Pulse lit dans Apple Santé, avant la modale native.
struct HealthAccessView: View {
    let model: OnboardingModel

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            OnboardingTitle(
                title: String(localized: "Pulse a besoin de lire tes nuits", bundle: .module),
                subtitle: String(
                    localized: "Sans ces données, pas de score de récupération mesuré. Elles restent sur ton iPhone.",
                    bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 14) {
                    OnboardingInfoRow(
                        systemImage: "waveform.path.ecg",
                        title: String(localized: "Variabilité cardiaque nocturne", bundle: .module),
                        detail: String(
                            localized: """
                                L'iPhone et l'Apple Watch fournissent la SDNN, pas la rMSSD : Pulse construit sa propre ligne \
                                de base sur cette mesure.
                                """,
                            bundle: .module))
                    OnboardingInfoRow(
                        systemImage: "moon.zzz.fill",
                        title: String(localized: "Phases de sommeil", bundle: .module),
                        detail: String(localized: "Durée, sommeil profond et paradoxal.", bundle: .module))
                    OnboardingInfoRow(
                        systemImage: "heart.fill",
                        title: String(localized: "Fréquence cardiaque au repos", bundle: .module),
                        detail: String(localized: "Mesurée pendant le sommeil.", bundle: .module))
                    OnboardingInfoRow(
                        systemImage: "clock.arrow.circlepath",
                        title: String(localized: "Entraînements passés", bundle: .module),
                        detail: String(
                            localized: "Pour calculer ta charge des 28 derniers jours dès aujourd'hui.", bundle: .module))
                }
            }
            Text(String(
                localized: """
                    Ce sont des données de santé au sens de l'article 9 du RGPD. Tu peux retirer l'accès à tout \
                    moment dans les réglages : Pulse bascule alors sur un check-in de trois questions.
                    """,
                bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
        } footer: {
            OnboardingButton(
                title: String(localized: "Autoriser dans Apple Santé", bundle: .module),
                identifier: OnboardingIdentifiers.healthAllow, style: PrimaryButtonStyle()
            ) { await model.allowHealth() }
            OnboardingButton(
                title: String(localized: "Continuer sans montre", bundle: .module),
                identifier: OnboardingIdentifiers.healthSkip, style: LinkButtonStyle()
            ) { await model.skipHealth() }
        }
    }
}

#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .health))
}
