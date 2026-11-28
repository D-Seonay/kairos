import PulseDesignSystem
import SwiftUI

/// « Ce que le score prend en compte » : nuits de la ligne de base VFC, origine de la FC au repos, dette de sommeil.
struct WhyDetailsSection: View {
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(String(localized: "Ce que le score prend en compte", bundle: .module))
            ObsidianCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(details, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(PulsePalette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
