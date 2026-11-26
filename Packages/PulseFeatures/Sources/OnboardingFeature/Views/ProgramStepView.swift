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
            WeekPreviewLegend()
            if model.requestedRuns > 0 {
                Text(String(localized: "Les sorties que demande ton curseur sont déjà placées dans chaque semaine.", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 10) {
                ForEach(model.templates) { template in
                    ProgramTemplateCard(
                        template: template, week: model.weekPreview(for: template),
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
                localized: "Pas de programme pour l'instant : tu crées tes propres routines dans l'onglet Séance.",
                bundle: .module),
            isSelected: model.choseCustomProgram
        ) { model.choseCustomProgram = true }
    }
}

/// La carte d'un modèle : nom, badge « Recommandé », résumé, séances par semaine, focus et aperçu de la semaine L à D telle que
/// l'adoption la donnera, sorties du curseur comprises.
struct ProgramTemplateCard: View {
    let template: ProgramTemplate
    let week: [WeekPreviewDay]
    let isRecommended: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        let shape = RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous)
        Button {
            guard !isSelected else { return }
            onSelect()
            PulseHaptics.selection()
        } label: {
            ObsidianCard {
                VStack(alignment: .leading, spacing: 10) {
                    header(palette)
                    Text(template.summary.fr)
                        .font(.subheadline)
                        .foregroundStyle(PulsePalette.text2)
                        .multilineTextAlignment(.leading)
                    tags(week)
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

    /// Le nom et le badge « Recommandé » sur une ligne ; le badge passe sous le nom aux tailles d'accessibilité.
    @ViewBuilder
    private func header(_ palette: AccentPalette) -> some View {
        let name = Text(template.name.fr)
            .font(.headline)
            .foregroundStyle(PulsePalette.text)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                name
                if isRecommended { recommendedBadge(palette) }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                name
                Spacer(minLength: 0)
                if isRecommended { recommendedBadge(palette) }
            }
        }
    }

    /// Les séances par semaine et le focus : côte à côte, ou l'un sous l'autre quand ils ne tiennent pas sur une ligne.
    private func tags(_ week: [WeekPreviewDay]) -> some View {
        let sessions = String(localized: "\(ProgramWeekPreview.sessionCount(week)) séances par semaine", bundle: .module)
        let focus = template.recommendedFor.focus.localizedName
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                tag(sessions)
                tag(focus)
            }
            VStack(alignment: .leading, spacing: 6) {
                tag(sessions)
                tag(focus)
            }
        }
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

/// Les sept jours L à D : la couleur ne porte pas seule le type de jour. Un pictogramme (haltère, coureur) marque une séance, et
/// un repos est tracé en pointillés.
struct WeekPreviewRow: View {
    let days: [WeekPreviewDay]
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days.indices, id: \.self) { index in
                cell(days[index])
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ProgramWeekPreview.accessibilityLabel(for: days))
    }

    private func cell(_ day: WeekPreviewDay) -> some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        return VStack(spacing: 2) {
            Text(day.weekday.onboardingInitial)
                .font(.system(.footnote, weight: .bold))
            if let systemImage = day.kind.systemImage {
                Image(systemName: systemImage)
                    .font(.caption2)
            }
        }
        .foregroundStyle(foreground(day.kind))
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(background(day.kind), in: shape)
        .overlay {
            if day.kind == .rest {
                shape.strokeBorder(PulsePalette.muted.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
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

/// La légende des aperçus de semaine : un pictogramme par type de jour, avec son nom. Les cartes la lisent déjà jour par jour à
/// VoiceOver, la légende est donc masquée.
struct WeekPreviewLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { items }
            VStack(alignment: .leading, spacing: 6) { items }
        }
        .font(.footnote)
        .foregroundStyle(PulsePalette.text2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var items: some View {
        item(WeekPreviewDay.Kind.strength.localizedName.capitalized) {
            if let image = WeekPreviewDay.Kind.strength.systemImage { Image(systemName: image) }
        }
        item(WeekPreviewDay.Kind.run.localizedName.capitalized) {
            if let image = WeekPreviewDay.Kind.run.systemImage { Image(systemName: image) }
        }
        item(WeekPreviewDay.Kind.rest.localizedName.capitalized) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(PulsePalette.muted.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 14, height: 14)
        }
    }

    private func item(_ title: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: 6) {
            mark()
            Text(title)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .program))
}

#Preview("Programme, accessibilité XL") {
    OnboardingFlowView(model: OnboardingPreviewSupport.model(step: .program))
        .dynamicTypeSize(.accessibility3)
}
#endif
