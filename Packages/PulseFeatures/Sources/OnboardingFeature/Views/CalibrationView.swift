import CheckInFeature
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Écran 6, `calibration` : la lecture des nuits, puis le premier score avec sa ligne de base, ou le check-in à sa place.
struct CalibrationView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        switch model.calibration {
        case .idle:
            ReadingView(progress: 0)
        case .reading(let progress):
            ReadingView(progress: progress)
        case .scored(let recovery, let baseline):
            ScoredView(model: model, recovery: recovery, baseline: baseline)
        case .needsCheckIn:
            checkIn
        }
    }

    /// Le titre, l'explication et le check-in défilent ensemble : à `accessibility3` ils débordent d'un écran.
    private var checkIn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Pas encore de score mesuré", bundle: .module))
                        .font(PulseFont.title(.title2))
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                }
                .padding(.bottom, 20)
                // L'erreur d'enregistrement s'affiche juste au-dessus du bouton du check-in, pas en haut de l'écran.
                CheckInView(form: model.checkIn, scrollable: false, errorMessage: model.errorMessage,
                            isSubmitting: model.isSubmittingCheckIn) { _ in
                    Task { await model.submitCheckIn() }
                }
            }
            .padding(PulseMetrics.spacing)
        }
        .background(PulsePalette.background)
        .pulseAnnounceError(model.errorMessage)
    }

    private var explanation: String {
        OnboardingCopy.calibrationExplanation(healthSkipped: model.healthSkipped)
    }
}

/// La lecture des 60 jours d'Apple Santé : une barre de progression et une phrase.
private struct ReadingView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: min(max(progress, 0), 1))
                .tint(PulsePalette.text)
                .frame(maxWidth: 240)
            Text(String(localized: "Lecture de tes nuits…", bundle: .module))
                .font(.headline)
                .foregroundStyle(PulsePalette.text)
            Text(String(localized: "Pulse calcule ta récupération de ce matin.", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
            Spacer()
            Spacer()
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Bonne nuit") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .goodNight))
}

#Preview("Trois nuits") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .threeNights))
}

#Preview("Bonne nuit, accessibilité XL") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .goodNight))
        .dynamicTypeSize(.accessibility3)
}

#Preview("Trois nuits, accessibilité XL") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .threeNights))
        .dynamicTypeSize(.accessibility3)
}
#endif
