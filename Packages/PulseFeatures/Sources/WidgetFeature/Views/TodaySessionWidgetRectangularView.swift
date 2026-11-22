import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget rectangulaire d'écran verrouillé pour la séance du jour (maquette `ios-verrouille`) :
/// icône et titre de séance, séries et ajustement, intensité cible.
public struct TodaySessionWidgetRectangularView: View {
    private let content: TodaySessionWidgetContent

    @ScaledMetric(relativeTo: .caption) private var detailSize = 12
    @ScaledMetric(relativeTo: .footnote) private var titleSize = 13
    @ScaledMetric(relativeTo: .caption) private var iconSize = 12

    public init(content: TodaySessionWidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleRow
            Text(content.accessorySubtitle)
                .font(.system(size: detailSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(content.accessoryDetail)
                .font(.system(size: detailSize))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Le rectangle de l'écran verrouillé fait 66 pt de haut : l'étiquette VoiceOver porte tout le texte.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: content.isRest ? "bed.double.fill" : "dumbbell.fill")
                .font(.system(size: iconSize))
            Text(content.accessoryTitle)
                .font(.system(size: titleSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

#Preview("Séance Rectangulaire") {
    TodaySessionWidgetRectangularView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .frame(width: 164, height: 66)
        .padding(8)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}

#Preview("Séance Rectangulaire, accessibilité 3") {
    TodaySessionWidgetRectangularView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .dynamicTypeSize(.accessibility3)
        .frame(width: 164, height: 66)
        .padding(8)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}
