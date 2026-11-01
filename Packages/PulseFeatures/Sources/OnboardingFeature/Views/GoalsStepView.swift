import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Écran 4, `objectifs` : curseur force / endurance, séances par semaine, jours de repos, matériel et douleurs.
struct GoalsStepView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            OnboardingTitle(
                title: String(localized: "Où placer le curseur ?", bundle: .module),
                subtitle: String(
                    localized: "Pulse répartit tes semaines entre force et endurance selon cet équilibre.", bundle: .module))
            sliderCard
            sessionsSection
            restDaysSection
            equipmentSection
            painSection
        } footer: {
            OnboardingButton(
                title: String(localized: "Continuer", bundle: .module), identifier: OnboardingIdentifiers.goalsContinue,
                style: PrimaryButtonStyle()
            ) { await model.continueFromGoals() }
        }
    }

    private var sliderCard: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 14) {
                FocusSlider(focus: $model.profile.focus)
                Divider().overlay(PulsePalette.line)
                let proposal = model.weekProposal
                Text(OnboardingCopy.proposal(strength: proposal.strength, runs: proposal.runs))
                    .font(.subheadline)
                    .foregroundStyle(PulsePalette.text2)
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingSectionTitle(String(localized: "Séances par semaine", bundle: .module))
            ChoicePills(
                options: (2...6).map { (value: $0, label: String($0)) },
                selection: model.optionalBinding(\.trainingDaysPerWeek))
        }
    }

    private var restDaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingSectionTitle(String(localized: "Jours de repos obligatoires", bundle: .module))
            WeekdayToggleRow(selection: restDaysBinding)
        }
    }

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingSectionTitle(String(localized: "Matériel accessible", bundle: .module))
            equipmentCard(
                .fullGym, systemImage: "building.2.fill", title: String(localized: "Salle complète", bundle: .module),
                detail: String(localized: "Barres, machines, poulies", bundle: .module))
            equipmentCard(
                .homeGym, systemImage: "house.fill", title: String(localized: "Home gym", bundle: .module),
                detail: String(localized: "Haltères, banc, élastiques", bundle: .module))
            equipmentCard(
                .bodyweight, systemImage: "figure.core.training", title: String(localized: "Poids du corps", bundle: .module),
                detail: String(localized: "Aucun matériel", bundle: .module))
        }
    }

    private func equipmentCard(_ access: EquipmentAccess, systemImage: String, title: String, detail: String) -> some View {
        OnboardingOptionCard(
            systemImage: systemImage, title: title, detail: detail, isSelected: model.profile.equipmentAccess == access
        ) { model.profile.equipmentAccess = access }
    }

    private var painSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingSectionTitle(String(localized: "Douleurs ou limitations actuelles", bundle: .module))
            MultiChoicePills(
                options: PainArea.allCases.map { (value: PainChoice.area($0), label: $0.onboardingName) }
                    + [(value: PainChoice.none, label: String(localized: "Aucune", bundle: .module))],
                selection: painBinding)
            Text(String(
                localized: "Les mouvements à risque pour les zones cochées sont remplacés par leur alternative.", bundle: .module))
                .font(.footnote)
                .foregroundStyle(PulsePalette.muted)
        }
    }

    // MARK: - Liens

    /// La rangée travaille sur un ensemble ; le profil garde les jours dans l'ordre de la semaine.
    private var restDaysBinding: Binding<Set<Weekday>> {
        Binding(
            get: { Set(model.profile.restWeekdays) },
            set: { newValue in model.profile.restWeekdays = Weekday.allCases.filter(newValue.contains) }
        )
    }

    private var painBinding: Binding<Set<PainChoice>> {
        Binding(
            get: { PainChoice.selection(for: model.profile.painAreas) },
            set: { newValue in
                model.profile.painAreas = PainChoice.areas(from: newValue, previous: model.profile.painAreas)
            }
        )
    }
}

#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .goals))
}
