import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget moyen de l'écran d'accueil pour la séance du jour (maquette `ios-accueil`) :
/// cartographie musculaire, titre de séance, badge ajustée, métadonnées et bouton d'action.
public struct TodaySessionWidgetMediumView: View {
    private let content: TodaySessionWidgetContent

    public init(content: TodaySessionWidgetContent) {
        self.content = content
    }

    public var body: some View {
        TodaySessionWidgetMediumViewBody(content: content)
            .dynamicTypeSize(...WidgetTypeCap.sessionMedium)
    }
}

/// Le contenu de la vue, plafonné par `TodaySessionWidgetMediumView` : ses `@ScaledMetric` lisent la taille déjà plafonnée.
struct TodaySessionWidgetMediumViewBody: View {
    let content: TodaySessionWidgetContent

    @ScaledMetric(relativeTo: .body) private var restIconSize = 26
    @ScaledMetric(relativeTo: .headline) private var titleSize = 16
    @ScaledMetric(relativeTo: .caption) private var metaSize = 12
    @ScaledMetric(relativeTo: .caption2) private var eyebrowSize = 11
    @ScaledMetric(relativeTo: .caption2) private var tagSize = 11
    @ScaledMetric(relativeTo: .caption) private var buttonSize = 12.5
    @ScaledMetric(relativeTo: .caption2) private var buttonIconSize = 11

    var body: some View {
        HStack(spacing: 14) {
            muscleMap
            details
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    @ViewBuilder
    private var muscleMap: some View {
        if !content.muscleLevels.isEmpty {
            MuscleMapView(levels: content.muscleLevels, label: content.title, height: 98)
                .frame(width: 88)
        } else {
            ZStack {
                Circle()
                    .fill(PulsePalette.surface2)
                    .frame(width: 64, height: 64)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: restIconSize))
                    .foregroundStyle(PulsePalette.muted)
            }
            .frame(width: 88)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            headerRow
            Text(content.title)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(PulsePalette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(content.metaText)
                .font(.system(size: metaSize))
                .foregroundStyle(PulsePalette.text2)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 2)
            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(TodaySessionWidgetContent.displayName)
                .font(.system(size: eyebrowSize, weight: .semibold))
                .foregroundStyle(PulsePalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if content.isAdjusted {
                adjustedTag
            }
        }
    }

    private var adjustedTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: tagSize, weight: .bold))
            Text(String(localized: "Ajustée", bundle: .module))
                .font(.system(size: tagSize, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(PulsePalette.accent(for: .amber).accent).opacity(0.18))
        .foregroundStyle(Color(PulsePalette.accent(for: .amber).accent))
        .clipShape(Capsule())
    }

    private var actionButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: buttonIconSize, weight: .bold))
            Text(content.buttonText)
                .font(.system(size: buttonSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 30)
        .background(Color(PulsePalette.accent(for: .amber).accent))
        .foregroundStyle(Color(PulsePalette.accent(for: .amber).accentInk))
        .clipShape(Capsule())
    }
}

#Preview("Moyen Séance du jour") {
    TodaySessionWidgetMediumView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .padding(16)
        .frame(width: 338, height: 158)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}

#Preview("Moyen Séance du jour, accessibilité 3") {
    TodaySessionWidgetMediumView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .dynamicTypeSize(.accessibility3)
        .padding(16)
        .frame(width: 338, height: 158)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}
