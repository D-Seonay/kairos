import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget circulaire d'écran verrouillé pour la série (maquette `ios-verrouille`) :
/// icône flamme et nombre de semaines en grand.
public struct StreakWidgetCircularView: View {
    private let content: StreakWidgetContent

    @ScaledMetric(relativeTo: .body) private var flameSize = 15
    @ScaledMetric(relativeTo: .title3) private var numberSize = 20

    public init(content: StreakWidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize))
            Text("\(content.streakWeeks)")
                .font(.system(size: numberSize, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Le cercle de l'écran verrouillé est fixe : l'étiquette VoiceOver porte tout le texte.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
