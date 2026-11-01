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

    private var checkIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Pas encore de score mesuré", bundle: .module))
                    .font(.system(.title2, weight: .heavy))
                    .foregroundStyle(PulsePalette.text)
                    .accessibilityAddTraits(.isHeader)
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
                if let message = model.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.bad)
                }
            }
            .padding([.horizontal, .top], PulseMetrics.spacing)
            CheckInView(form: model.checkIn) { _ in
                Task { await model.submitCheckIn() }
            }
        }
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

#Preview("Bonne nuit") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .goodNight))
}

#Preview("Trois nuits") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .calibration, scenario: .threeNights))
}
