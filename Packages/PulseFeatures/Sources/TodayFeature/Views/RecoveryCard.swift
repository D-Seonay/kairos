import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// La carte opale de récupération : catégorie, jauge, marqueur et les trois facteurs de la nuit ; la toucher ouvre l'écran « Pourquoi ».
/// Avant 4 h, elle montre le score de la veille. `.needsCheckIn` n'est pas une carte : l'accueil affiche alors le check-in.
struct RecoveryCard: View {
    let score: TodayScore?
    let factors: [FactorDisplay]
    let marker: String?
    var onWhy: () -> Void = {}

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
        OpalCard {
            VStack(spacing: 16) {
                CardHeader(title: String(localized: "Récupération", bundle: .module), category: recovery.category, marker: marker)
                RecoveryGauge(score: recovery.score, category: recovery.category, style: .large)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier(TodayIdentifiers.score)
                    .accessibilityAction(named: Text(String(localized: "Pourquoi ce score ?", bundle: .module)), onWhy)
                FactorColumns(factors: factors)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous))
        .onTapGesture(perform: onWhy)
    }

    // MARK: - Veille

    private func yesterdayCard(_ yesterday: DailyRecovery?) -> some View {
        OpalCard {
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

    private var placeholderCard: some View {
        OpalCard {
            VStack(spacing: 16) {
                CardHeader(title: String(localized: "Récupération", bundle: .module), category: nil, marker: nil)
                RecoveryGauge(score: nil, category: nil, style: .large)
                    .frame(maxWidth: .infinity)
            }
        }
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulsePalette.opalMuted)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var badge: some View {
        if let category {
            CategoryBadge(category: category, marker: marker, onOpal: true)
        }
    }
}

/// Sommeil, variabilité, FC repos : côte à côte, empilées aux tailles d'accessibilité.
private struct FactorColumns: View {
    let factors: [FactorDisplay]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulsePalette.opalMuted)
            Text(factor.value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(factor.isMissing ? PulsePalette.opalMuted : PulsePalette.opalInk)
            Text(factor.detail)
                .font(.caption)
                .foregroundStyle(PulsePalette.opalMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
