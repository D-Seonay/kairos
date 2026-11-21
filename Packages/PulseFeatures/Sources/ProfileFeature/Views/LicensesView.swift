import PulseDesignSystem
import SwiftUI

/// Les licences et les sources (spec M7 §15) : les silhouettes de la carte musculaire, les deux formules de Pulse et les polices.
struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text(MuscleMapArtwork.bundled.license)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .textSelection(.enabled)
                    .padding(.vertical, 6)
            } header: {
                Text(String(localized: "Carte musculaire", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
            Section {
                line(String(localized: "1RM estimé : formule de Brzycki (1993)", bundle: .module))
                line(String(localized: "FC max : formule de Tanaka (2001), 208 − 0,7 × âge", bundle: .module))
                line(String(localized: "Polices : SF Pro et SF Mono, Apple", bundle: .module))
            } header: {
                Text(String(localized: "Sources", bundle: .module))
            }
            .listRowBackground(PulsePalette.surface)
        }
        .scrollContentBackground(.hidden)
        .pulseScreenBackground(aura: 0.5)
        .navigationTitle(String(localized: "Licences", bundle: .module))
        .pulseInlineTitle()
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44, alignment: .leading)
    }
}

#if DEBUG
#Preview("Licences") {
    NavigationStack {
        LicensesView()
    }
    .preferredColorScheme(.light)
}
#endif
