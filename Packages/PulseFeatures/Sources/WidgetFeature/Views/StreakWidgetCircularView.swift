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
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 15))
            Text("\(content.streakWeeks)")
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
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
