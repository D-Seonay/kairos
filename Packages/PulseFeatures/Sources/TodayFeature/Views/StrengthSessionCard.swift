import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La carte d'une séance de musculation : titre, badge « Ajustée » ou « Planifiée », mini-carte musculaire et résumé,
/// « Pourquoi ? » et « Rétablir la séance d'origine » côte à côte. « Démarrer » n'est pas dans la carte : l'accueil l'ancre en bas de
/// l'écran, sous le pouce (`TodayView`).
struct StrengthSessionCard: View {
    let card: StrengthCard
    let onWhy: () -> Void
    let onOrigin: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SessionCardHeader(title: card.title, badge: card.badge)
        SessionOverview(summary: card.summary)
        if card.showsWhy || card.originButton != nil {
            secondaryButtons
        }
    }

    /// Côte à côte, empilés aux tailles d'accessibilité.
    private var secondaryButtons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            if card.showsWhy {
                Button(String(localized: "Pourquoi ?", bundle: .module), action: onWhy)
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier(TodayIdentifiers.sessionWhy)
            }
            if let origin = card.originButton {
                Button(origin, action: onOrigin)
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier(TodayIdentifiers.sessionOrigin)
            }
        }
    }
}

/// « Séance du jour », le titre de la séance (précédé d'un coureur un jour de course) et, s'il y a lieu, le badge.
struct SessionCardHeader: View {
    let title: String
    var badge: StrengthCard.Badge?
    var runIcon = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Le titre et le badge côte à côte, empilés aux tailles d'accessibilité.
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Séance du jour", bundle: .module))
                    .pulseEyebrow()
                HStack(spacing: 10) {
                    if runIcon {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundStyle(PulsePalette.run)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(PulsePalette.text)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(TodayIdentifiers.sessionTitle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let badge {
                SessionBadge(badge: badge)
            }
        }
    }
}

/// « Ajustée » et « Décharge » en couleur d'accent, « Planifiée » en neutre ; le mot est toujours écrit.
private struct SessionBadge: View {
    let badge: StrengthCard.Badge
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Label {
            Text(text)
        } icon: {
            switch badge {
            case .adjusted: Image(systemName: "sparkles")
            case .deload: Image(systemName: "arrow.down.right")
            case .planned: EmptyView()
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(badge == .planned ? PulsePalette.text2 : Color(palette.accent))
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .padding(.horizontal, 10)
        .frame(minHeight: 24)
        .background(badge == .planned ? PulsePalette.surface2 : palette.soft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var text: String {
        switch badge {
        case .adjusted: String(localized: "Ajustée", bundle: .module)
        case .planned: String(localized: "Planifiée", bundle: .module)
        case .deload: String(localized: "Décharge", bundle: .module)
        }
    }
}

/// Mini-carte musculaire, séries, durée, RPE maximum et trois muscles principaux ; empilés aux tailles d'accessibilité.
/// VoiceOver lit une seule phrase (`SessionSummary.spokenText`) : la carte et les listes visibles sont muettes.
private struct SessionOverview: View {
    let summary: SessionSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        layout {
            MuscleMapView(levels: MuscleIntensity.levels(weights: summary.muscleWeights), label: musclesLabel, height: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.statsText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
                if !summary.topMuscles.isEmpty {
                    Text(summary.topMuscles.map(\.localizedName).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.spokenText)
    }

    /// La carte musculaire dit chaque muscle et son intensité ; la phrase du conteneur la masque, elle reste juste si on la sort.
    private var musclesLabel: String {
        MuscleMapSummary.text(levels: MuscleIntensity.byMuscle(weights: summary.muscleWeights))
    }

}

#if DEBUG
#Preview("Séance, accessibilité 3") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            StrengthSessionCard(card: StrengthCard(
                title: "Push", badge: .adjusted,
                summary: SessionSummary(setCount: 19, estimatedMinutes: 55, maxRPE: 7.5, topMuscles: [.chest, .triceps, .frontDelts],
                                        muscleWeights: [.chest: 10, .triceps: 6, .frontDelts: 4]),
                showsWhy: true, originButton: "Rétablir la séance d'origine", startButton: "Démarrer la séance"),
                                onWhy: {}, onOrigin: {})
        }
        .padding()
    }
    .background(PulsePalette.background)
    .dynamicTypeSize(.accessibility3)
}
#endif
