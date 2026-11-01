import PulseDomain
import SwiftUI

/// Pastille de catégorie : le nom est toujours écrit, la couleur s'y ajoute. `marker` : « Estimé », « En calibration ».
/// `onOpal` choisit les teintes sombres lisibles sur une carte opale (blanche).
public struct CategoryBadge: View {
    private let category: RecoveryCategory
    private let marker: String?
    let onOpal: Bool

    public init(category: RecoveryCategory, marker: String? = nil, onOpal: Bool = false) {
        self.category = category
        self.marker = marker
        self.onOpal = onOpal
    }

    public var body: some View {
        Text(text)
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(category.tone.color(onOpal: onOpal))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(category.tone.softColor(onOpal: onOpal), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }

    private var text: String {
        guard let marker else { return category.localizedName }
        return "\(category.localizedName) · \(marker)"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        CategoryBadge(category: .optimal)
        CategoryBadge(category: .normal, marker: "Estimé")
        CategoryBadge(category: .moderateFatigue)
        CategoryBadge(category: .overreached, marker: "En calibration")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PulsePalette.background)
}

#Preview("Sur carte opale") {
    OpalCard {
        VStack(alignment: .leading, spacing: 10) {
            CategoryBadge(category: .optimal, onOpal: true)
            CategoryBadge(category: .moderateFatigue, marker: "Estimé", onOpal: true)
            CategoryBadge(category: .overreached, onOpal: true)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(PulsePalette.background)
}
