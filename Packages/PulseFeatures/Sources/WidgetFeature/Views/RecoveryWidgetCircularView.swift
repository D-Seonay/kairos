import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le widget circulaire de l'écran verrouillé (maquette `ios-verrouille`) : la jauge et le score, sans autre texte.
/// L'écran verrouillé le rend en monochrome : la forme de l'arc et le chiffre portent l'information.
public struct RecoveryWidgetCircularView: View {
    private let content: RecoveryWidgetContent

    public init(content: RecoveryWidgetContent) {
        self.content = content
    }

    public var body: some View {
        RecoveryGauge(score: content.score.map(Double.init), category: content.category, style: .compact)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.accessibilityLabel)
    }
}

#Preview("Score du jour") {
    RecoveryWidgetCircularView(content: .sample(at: Date(timeIntervalSinceReferenceDate: 0), calendar: Calendar(identifier: .gregorian)))
        .frame(width: 76, height: 76)
        .background(.white.opacity(0.18), in: Circle())
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}

#Preview("Pas encore prêt") {
    RecoveryWidgetCircularView(content: .make(snapshot: nil, at: Date(timeIntervalSinceReferenceDate: 0),
                                              calendar: Calendar(identifier: .gregorian)))
        .frame(width: 76, height: 76)
        .background(.white.opacity(0.18), in: Circle())
        .foregroundStyle(.white)
        .padding()
        .background(.black)
}
