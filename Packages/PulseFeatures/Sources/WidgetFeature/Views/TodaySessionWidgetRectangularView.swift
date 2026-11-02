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
        VStack(alignment: .leading, spacing: 2) {
            titleRow
            Text(content.accessorySubtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(content.accessoryDetail)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }

    private var titleRow: some View {
        HStack(spacing: 5) {
            Image(systemName: content.isRest ? "bed.double.fill" : "dumbbell.fill")
                .font(.system(size: 12))
            Text(content.accessoryTitle)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
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
