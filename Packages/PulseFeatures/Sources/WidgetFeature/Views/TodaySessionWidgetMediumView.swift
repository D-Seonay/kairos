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
        HStack(spacing: 14) {
            muscleMap
            details
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                    .font(.system(size: 26))
                    .foregroundStyle(PulsePalette.muted)
            }
            .frame(width: 88)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            headerRow
            Text(content.title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(PulsePalette.text)
                .lineLimit(1)
            Text(content.metaText)
                .font(.system(size: 12))
                .foregroundStyle(PulsePalette.text2)
                .lineLimit(1)
            Spacer(minLength: 2)
            actionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(TodaySessionWidgetContent.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PulsePalette.muted)
                .lineLimit(1)
            if content.isAdjusted {
                adjustedTag
            }
        }
    }

    private var adjustedTag: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 8, weight: .bold))
            Text(String(localized: "Ajustée", bundle: .module))
                .font(.system(size: 9.5, weight: .bold))
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
                .font(.system(size: 10, weight: .bold))
            Text(content.buttonText)
                .font(.system(size: 12.5, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 30)
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
