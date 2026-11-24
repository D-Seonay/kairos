import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget rectangulaire d'écran verrouillé pour la séance du jour (maquette `ios-verrouille`) :
/// icône et titre de séance, séries et ajustement, intensité cible.
public struct TodaySessionWidgetRectangularView: View {
    private let content: TodaySessionWidgetContent

    public init(content: TodaySessionWidgetContent) {
        self.content = content
    }

    public var body: some View {
        TodaySessionWidgetRectangularViewBody(content: content)
            .dynamicTypeSize(...WidgetTypeCap.sessionRectangular)
    }
}

/// Le contenu de la vue, plafonné par `TodaySessionWidgetRectangularView` : ses `@ScaledMetric` lisent la taille déjà plafonnée.
struct TodaySessionWidgetRectangularViewBody: View {
    let content: TodaySessionWidgetContent

    @ScaledMetric(relativeTo: .caption) private var detailSize = 12
    @ScaledMetric(relativeTo: .footnote) private var titleSize = 13
    @ScaledMetric(relativeTo: .caption) private var iconSize = 12

    var body: some View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: iconSize))
            Text(content.accessoryTitle)
                .font(.system(size: titleSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    /// Sans séance chargée, une flèche de rechargement plutôt qu'une haltère ou un lit.
    private var iconName: String {
        guard content.isReady else { return "arrow.clockwise" }
        return content.isRest ? "bed.double.fill" : "dumbbell.fill"
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
