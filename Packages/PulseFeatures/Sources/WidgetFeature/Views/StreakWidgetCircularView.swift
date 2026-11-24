import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget circulaire d'écran verrouillé pour la série (maquette `ios-verrouille`) :
/// icône flamme et nombre de semaines en grand.
public struct StreakWidgetCircularView: View {
    private let content: StreakWidgetContent

    public init(content: StreakWidgetContent) {
        self.content = content
    }

    public var body: some View {
        StreakWidgetCircularViewBody(content: content)
            .dynamicTypeSize(...WidgetTypeCap.streakCircular)
    }
}

/// Le contenu de la vue, plafonné par `StreakWidgetCircularView` : ses `@ScaledMetric` lisent la taille déjà plafonnée.
struct StreakWidgetCircularViewBody: View {
    let content: StreakWidgetContent

    @ScaledMetric(relativeTo: .body) private var flameSize = 15
    @ScaledMetric(relativeTo: .title3) private var numberSize = 20

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize))
            Text(verbatim: content.weeksText)
                .font(.system(size: numberSize, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

#Preview("Streak Circulaire") {
    StreakWidgetCircularView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .frame(width: 76, height: 76)
        .background(.white.opacity(0.18), in: Circle())
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}

#Preview("Streak Circulaire, accessibilité 3") {
    StreakWidgetCircularView(content: .sample(at: Date(), calendar: Calendar(identifier: .gregorian)))
        .dynamicTypeSize(.accessibility3)
        .frame(width: 76, height: 76)
        .background(.white.opacity(0.18), in: Circle())
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}
