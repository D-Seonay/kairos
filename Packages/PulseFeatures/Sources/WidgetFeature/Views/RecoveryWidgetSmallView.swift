import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Le petit widget de l'écran d'accueil (maquette `ios-accueil`) : « Récupération », la jauge compacte, la catégorie en gras, la séance.
/// Les couleurs suivent le `foregroundStyle` de l'environnement : l'extension pose l'encre sur le fond opale, et laisse le système
/// teinter en monochrome (En veille la nuit) ; la lisibilité ne repose que sur la luminance, jamais sur la couleur seule.
public struct RecoveryWidgetSmallView: View {
    private let content: RecoveryWidgetContent

    public init(content: RecoveryWidgetContent) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(RecoveryWidgetContent.displayName)
            } icon: {
                Image(systemName: "heart.fill")
            }
            .font(.system(.caption2, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            RecoveryGauge(score: content.score.map(Double.init), category: content.category, style: .compact, animatesReveal: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 1) {
                Text(content.categoryText)
                    .font(.system(.footnote, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let footer = content.footer {
                    Text(footer)
                        .font(.system(.caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Un widget de 158 pt n'a pas la place des tailles d'accessibilité : l'étiquette VoiceOver porte tout le texte.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

#Preview("Séance allégée, sur opale") {
    RecoveryWidgetSmallView(content: .sample(at: Date(timeIntervalSinceReferenceDate: 0), calendar: Calendar(identifier: .gregorian)))
        .foregroundStyle(PulsePalette.opalInk)
        .padding(16)
        .frame(width: 158, height: 158)
        .background(PulsePalette.opal, in: RoundedRectangle(cornerRadius: 22))
        .padding()
}

#Preview("Pas encore prêt, monochrome sombre") {
    RecoveryWidgetSmallView(content: .make(snapshot: nil, at: Date(timeIntervalSinceReferenceDate: 0),
                                           calendar: Calendar(identifier: .gregorian)))
        .padding(16)
        .frame(width: 158, height: 158)
        .background(.black, in: RoundedRectangle(cornerRadius: 22))
        .foregroundStyle(.white)
        .padding()
}
