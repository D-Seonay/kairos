import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La dalle tramée de récupération, dont la lumière suit le score : catégorie, jauge, marqueur, les trois facteurs de la
/// nuit et le lien « Pourquoi ce score » ; toucher la dalle ouvre aussi l'écran « Pourquoi ».
/// Avant 4 h, elle montre le score de la veille. `.needsCheckIn` n'est pas une carte : l'accueil affiche alors le check-in.
struct RecoveryCard: View {
    let score: TodayScore?
    let factors: [FactorDisplay]
    let marker: String?
    /// Le marqueur tel que VoiceOver le dit (« estimé », « en calibration, 9 nuits »).
    var spokenMarker: String?
    var onWhy: () -> Void = {}
    /// Sans score : la lecture d'Apple Santé est en cours (indicateur) ou a échoué (message et façon de réessayer).
    var isLoading = false
    var scoreFailed = false

    var body: some View {
        switch score {
        case .scored(let recovery):
            scoredCard(recovery)
        case .beforeDayStart(let yesterday):
            yesterdayCard(yesterday)
        case .needsCheckIn, nil:
            placeholderCard
        }
    }

    // MARK: - Score du jour

    /// Toucher la carte ouvre « Pourquoi ». La jauge reste un texte à part (les tests d'interface la lisent) : VoiceOver y trouve
    /// l'action « Pourquoi ce score ? ».
    private func scoredCard(_ recovery: DailyRecovery) -> some View {
        OpalCard(heat: recovery.score) {
            VStack(spacing: 16) {
                CardHeader(title: String(localized: "Récupération", bundle: .module), category: recovery.category, marker: marker)
                // La jauge dit aussi la catégorie et le marqueur : la pastille de l'en-tête n'est pas relue.
                RecoveryGauge(score: recovery.score, category: recovery.category, style: .large,
                              accessibilityLabel: RecoveryCardText.gaugeLabel(recovery: recovery, marker: spokenMarker))
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier(TodayIdentifiers.score)
                    .accessibilityAction(named: Text(String(localized: "Pourquoi ce score ?", bundle: .module)), onWhy)
                FactorColumns(factors: factors)
                WhyLink(action: onWhy)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseMetrics.radiusHero, style: .continuous))
        .onTapGesture(perform: onWhy)
    }

    // MARK: - Veille

    private func yesterdayCard(_ yesterday: DailyRecovery?) -> some View {
        OpalCard(heat: yesterday?.score) {
            VStack(spacing: 16) {
                CardHeader(title: String(localized: "Score d'hier", bundle: .module), category: yesterday?.category, marker: nil)
                RecoveryGauge(score: yesterday?.score, category: yesterday?.category, style: .large)
                    .frame(maxWidth: .infinity)
                Text(yesterday == nil ? Self.noYesterdayNote : Self.afterDayStartNote)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.opalMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private static var afterDayStartNote: String {
        String(localized: "Le score du jour se calcule après 4 h", bundle: .module)
    }

    private static var noYesterdayNote: String {
        String(localized: "Pas de score hier. Le score du jour se calcule après 4 h", bundle: .module)
    }

    // MARK: - Avant la première lecture

    /// La jauge vide, avec ce qui se passe : la lecture en cours, ou l'échec du calcul et comment réessayer. Jamais un « — » muet.
    private var placeholderCard: some View {
        OpalCard {
            VStack(spacing: 16) {
                CardHeader(title: String(localized: "Récupération", bundle: .module), category: nil, marker: nil)
                RecoveryGauge(score: nil, category: nil, style: .large)
                    .frame(maxWidth: .infinity)
                placeholderStatus
            }
        }
    }

    @ViewBuilder
    private var placeholderStatus: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(PulsePalette.opalInk)
                Text(String(localized: "Lecture d'Apple Santé…", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.opalMuted)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        } else if scoreFailed {
            Text(Self.failedNote)
                .font(.footnote)
                .foregroundStyle(PulsePalette.opalMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    private static var failedNote: String {
        String(localized: "Pulse n'a pas pu calculer ton score. Tire l'écran vers le bas pour réessayer.", bundle: .module)
    }
}

/// « Récupération » et la pastille de catégorie ; la pastille passe sous le titre quand le texte grandit.
private struct CardHeader: View {
    let title: String
    let category: RecoveryCategory?
    let marker: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                titleText
                Spacer(minLength: 8)
                badge
            }
            VStack(alignment: .leading, spacing: 8) {
                titleText
                badge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: some View {
        Text(title)
            .pulseEyebrow(PulsePalette.opalMuted)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var badge: some View {
        if let category {
            // La jauge de la carte dit déjà la catégorie et le marqueur.
            CategoryBadge(category: category, marker: marker, onOpal: true)
                .accessibilityHidden(true)
        }
    }
}

/// « Pourquoi ce score » en bas de la dalle : toute la dalle s'ouvre au toucher, ce lien le montre et donne une cible nette.
private struct WhyLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(String(localized: "Pourquoi ce score", bundle: .module))
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(PulsePalette.opalInk)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(alignment: .top) { PulsePalette.opalLine.frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Sommeil, variabilité, FC repos : côte à côte, empilées dès les grandes tailles de texte (xxLarge) : trois colonnes ne
/// tiennent plus sans tronquer « Variabilité ».
private struct FactorColumns: View {
    let factors: [FactorDisplay]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
        layout {
            ForEach(factors, id: \.factor) { factor in
                column(factor)
            }
        }
    }

    private func column(_ factor: FactorDisplay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(factor.title)
                .pulseEyebrow(PulsePalette.opalMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(factor.value)
                .font(PulseFont.value(.title2, weight: .regular))
                .foregroundStyle(factor.isMissing ? PulsePalette.opalMuted : PulsePalette.opalInk)
            Text(factor.detail)
                .font(.caption)
                .foregroundStyle(PulsePalette.opalMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(factor.accessibilityLabel)
    }
}
