import SwiftUI

/// Écran provisoire d'un onglet dont le contenu arrive avec un jalon ultérieur.
public struct ComingSoonView: View {
    private let title: String
    private let milestone: String

    public init(title: String, milestone: String) {
        self.title = title
        self.milestone = milestone
    }

    public var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.largeTitle)
                .foregroundStyle(PulsePalette.muted)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.title2, weight: .heavy))
                .foregroundStyle(PulsePalette.text)
            Text(String(localized: "Bientôt disponible, prévu au jalon \(milestone).", bundle: .module))
                .font(.subheadline)
                .foregroundStyle(PulsePalette.text2)
                .multilineTextAlignment(.center)
        }
        .padding(PulseMetrics.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ComingSoonView(title: "Séances", milestone: "M4")
        .background(PulsePalette.background)
}
