import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le petit widget de l'écran d'accueil pour la prochaine séance (maquette `ios-page2`) :
/// horaire en couleur run, titre de la séance, zone cardiaque et graduation des 5 zones.
public struct NextWorkoutWidgetSmallView: View {
    private let content: NextWorkoutWidgetContent

    public init(content: NextWorkoutWidgetContent) {
        self.content = content
    }

    public var body: some View {
        NextWorkoutWidgetSmallViewBody(content: content)
            .dynamicTypeSize(...WidgetTypeCap.nextWorkoutSmall)
    }
}

/// Le contenu de la vue, plafonné par `NextWorkoutWidgetSmallView` : ses `@ScaledMetric` lisent la taille déjà plafonnée.
struct NextWorkoutWidgetSmallViewBody: View {
    let content: NextWorkoutWidgetContent

    @ScaledMetric(relativeTo: .caption) private var headerSize = 12
    @ScaledMetric(relativeTo: .title3) private var titleSize = 19
    @ScaledMetric(relativeTo: .caption) private var zoneSize = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 4)
            sessionTitle
            Spacer(minLength: 4)
            zoneLabel
            Spacer(minLength: 8)
            zoneBars
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var header: some View {
        Label {
            Text(content.timingText)
        } icon: {
            Image(systemName: "figure.run")
        }
        .font(.system(size: headerSize, weight: .bold))
        .foregroundStyle(PulsePalette.run)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var sessionTitle: some View {
        Text(content.title)
            .font(.system(size: titleSize, weight: .semibold))
            .foregroundStyle(PulsePalette.text)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }

    private var zoneLabel: some View {
        Text(content.zoneText)
            .font(.system(size: zoneSize))
            .foregroundStyle(PulsePalette.text2)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
    }

    private var zoneBars: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { zone in
                let isActive = zone == content.activeZone
                Capsule()
                    .fill(isActive ? PulsePalette.run : PulsePalette.surface2)
                    .frame(height: 5)
            }
        }
    }
}

#Preview("Petit Prochaine séance Widget") {
    NextWorkoutWidgetSmallView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .padding(16)
        .frame(width: 158, height: 158)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}

#Preview("Petit Prochaine séance Widget, accessibilité 3") {
    NextWorkoutWidgetSmallView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .dynamicTypeSize(.accessibility3)
        .padding(16)
        .frame(width: 158, height: 158)
        .background(PulsePalette.surface, in: RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(PulsePalette.background)
}
