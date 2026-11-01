import PulseContent
import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Écran 5, « Ton programme » (sans maquette) : les modèles en cartes, le recommandé en tête, puis « Je construis le mien ».
struct ProgramStepView: View {
    @Bindable var model: OnboardingModel
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        OnboardingScreen(errorMessage: model.errorMessage) {
            OnboardingTitle(
                title: String(localized: "Ton programme", bundle: .module),
                subtitle: String(
                    localized: """
                        Pulse l'adapte à ton matériel, à tes douleurs et à tes jours de repos. Celui qui colle le mieux\
                         à ton curseur est en tête.
                        """,
                    bundle: .module))
            VStack(spacing: 10) {
                ForEach(model.templates) { template in
                    ProgramTemplateCard(
                        template: template, restWeekdays: model.profile.restWeekdays,
                        isRecommended: template.id == model.recommendedTemplateID,
                        isSelected: !model.choseCustomProgram && model.selectedTemplateID == template.id
                    ) {
                        model.selectedTemplateID = template.id
                        model.choseCustomProgram = false
                    }
                }
                customCard
            }
        } footer: {
            OnboardingButton(
                title: model.choseCustomProgram
                    ? String(localized: "Continuer sans programme", bundle: .module)
                    : String(localized: "Adopter ce programme", bundle: .module),
                identifier: OnboardingIdentifiers.programAdopt, style: PrimaryButtonStyle()
            ) { await model.adoptProgram() }
        }
    }

    private var customCard: some View {
        OnboardingOptionCard(
            systemImage: "square.and.pencil", title: String(localized: "Je construis le mien", bundle: .module),
            detail: String(
                localized: "Pas de programme pour l'instant : tu créeras tes propres routines dès que l'éditeur sera disponible.",
                bundle: .module),
            isSelected: model.choseCustomProgram
        ) { model.choseCustomProgram = true }
    }
}

/// La carte d'un modèle : nom, badge « Recommandé », résumé, séances par semaine, focus et aperçu de la semaine L à D.
struct ProgramTemplateCard: View {
    let template: ProgramTemplate
    let restWeekdays: [Weekday]
    let isRecommended: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous)
        let week = ProgramWeekPreview.days(for: template, restWeekdays: restWeekdays)
        Button {
            guard !isSelected else { return }
            onSelect()
            PulseHaptics.selection()
        } label: {
            ObsidianCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(template.name.fr)
                            .font(.headline)
                            .foregroundStyle(PulsePalette.text)
                        Spacer(minLength: 0)
                        if isRecommended { recommendedBadge(palette) }
                    }
                    Text(template.summary.fr)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        tag(String(localized: "\(ProgramWeekPreview.sessionCount(week)) séances par semaine", bundle: .module))
                        tag(template.recommendedFor.focus.localizedName)
                    }
                    WeekPreviewRow(days: week)
                }
            }
            .overlay(shape.strokeBorder(isSelected ? Color(palette.accent) : .clear, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func recommendedBadge(_ palette: AccentPalette) -> some View {
        Text(String(localized: "Recommandé", bundle: .module))
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(Color(palette.accent))
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(palette.soft, in: Capsule())
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(PulsePalette.text2)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(PulsePalette.surface2, in: Capsule())
    }
}

/// Les sept jours L à D : musculation en accent, course en cyan, repos en gris.
struct WeekPreviewRow: View {
    let days: [WeekPreviewDay]
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                let day = days[index]
                Text(day.weekday.onboardingInitial)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(foreground(day.kind))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(background(day.kind), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProgramWeekPreview.accessibilityLabel(for: days))
    }

    private func foreground(_ kind: WeekPreviewDay.Kind) -> Color {
        switch kind {
        case .strength: Color(PulsePalette.accent(for: theme).accent)
        case .run: PulsePalette.run
        case .rest: PulsePalette.muted
        }
    }

    private func background(_ kind: WeekPreviewDay.Kind) -> Color {
        switch kind {
        case .strength: PulsePalette.accent(for: theme).soft
        case .run: PulsePalette.runSoft
        case .rest: PulsePalette.surface2
        }
    }
}

#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .program))
}
