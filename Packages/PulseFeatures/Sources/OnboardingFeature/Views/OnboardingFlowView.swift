import PulseDesignSystem
import SwiftUI

/// Le parcours de premier lancement : fond, aura, barre d'étapes et bouton retour, puis l'écran de l'étape courante.
public struct OnboardingFlowView: View {
    @Bindable private var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: OnboardingModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            PulsePalette.background.ignoresSafeArea()
            AuraBackground().ignoresSafeArea()
            if model.hasStarted {
                VStack(spacing: 0) {
                    header
                    content
                        .id(model.step)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.step)
        .task { await model.start() }
        .task(id: model.step) { await stepDidChange() }
    }

    /// Barre d'étapes à partir de l'écran Apple Santé, bouton retour à partir du profil (sauf pendant la lecture des nuits).
    @ViewBuilder
    private var header: some View {
        if model.step.rawValue >= OnboardingStep.health.rawValue {
            HStack(spacing: 12) {
                if model.canGoBack {
                    Button {
                        model.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PulsePalette.text)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Retour", bundle: .module))
                } else if model.step.rawValue >= OnboardingStep.profile.rawValue {
                    Color.clear.frame(width: 44, height: 44)
                }
                StepProgressBar(current: model.step.rawValue, total: OnboardingStep.allCases.count - 1)
            }
            .padding(.horizontal, PulseMetrics.spacing)
            .padding(.top, 6)
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome: WelcomeView(model: model)
        case .health: HealthAccessView(model: model)
        case .profile: ProfileStepView(model: model)
        case .goals: GoalsStepView(model: model)
        case .program: ProgramStepView(model: model)
        case .calibration: CalibrationView(model: model)
        }
    }

    /// Un profil terminé a pu arriver d'iCloud ; et une reprise sur la calibration doit la relancer d'elle-même.
    private func stepDidChange() async {
        if await model.checkForRestoredProfile() { return }
        await model.resumeCalibrationIfNeeded()
    }
}

#if DEBUG
#Preview("Parcours") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .welcome))
}
#endif
