import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La carte d'une séance de musculation : titre, badge « Ajustée » ou « Planifiée », mini-carte musculaire et résumé,
/// « Pourquoi ? » et « Séance d'origine » côte à côte, puis « Démarrer ».
struct StrengthSessionCard: View {
    let card: StrengthCard
    /// `nil` tant que l'écran « Pourquoi » n'existe pas : le bouton est alors grisé.
    let onWhy: (() -> Void)?
    let onOrigin: () -> Void
    let onStart: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SessionCardHeader(title: card.title, badge: card.badge)
        SessionOverview(summary: card.summary)
        if card.showsWhy || card.originButton != nil {
            secondaryButtons
        }
        Button(card.startButton, action: onStart)
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier(TodayIdentifiers.sessionStart)
    }

    /// Côte à côte, empilés aux tailles d'accessibilité.
    private var secondaryButtons: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            if card.showsWhy {
                Button(String(localized: "Pourquoi ?", bundle: .module)) { onWhy?() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(onWhy == nil)
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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Séance du jour", bundle: .module))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulsePalette.muted)
                HStack(spacing: 10) {
                    if runIcon {
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundStyle(PulsePalette.run)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(.title3.weight(.bold))
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

/// « Ajustée » en couleur d'accent, « Planifiée » en neutre ; le mot est toujours écrit.
private struct SessionBadge: View {
    let badge: StrengthCard.Badge
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        let palette = PulsePalette.accent(for: theme)
        Label {
            Text(text)
        } icon: {
            if badge == .adjusted {
                Image(systemName: "sparkles")
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(badge == .adjusted ? Color(palette.accent) : PulsePalette.text2)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .frame(minHeight: 24)
        .background(badge == .adjusted ? palette.soft : PulsePalette.surface2, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private var text: String {
        switch badge {
        case .adjusted: String(localized: "Ajustée", bundle: .module)
        case .planned: String(localized: "Planifiée", bundle: .module)
        }
    }
}

/// Mini-carte musculaire, séries, durée, RPE maximum et trois muscles principaux ; empilés aux tailles d'accessibilité.
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
                Text(statsText)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulsePalette.text)
                if !summary.topMuscles.isEmpty {
                    Text(summary.topMuscles.map(\.localizedName).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(PulsePalette.text2)
                }
            }
        }
    }

    private var musclesLabel: String {
        let names = summary.topMuscles.map(\.localizedName).joined(separator: ", ")
        return String(localized: "Muscles sollicités : \(names)", bundle: .module)
    }

    /// « 19 séries · ~ 55 min · RPE max 8 ».
    private var statsText: String {
        let sets = String(localized: "\(summary.setCount) séries", bundle: .module)
        let duration = String(localized: "~ \(PulseFormat.duration(minutes: summary.estimatedMinutes))", bundle: .module)
        let rpe = PulseFormat.decimal(summary.maxRPE, maxFractionDigits: 1)
        return [sets, duration, String(localized: "RPE max \(rpe)", bundle: .module)].joined(separator: " · ")
    }
}
