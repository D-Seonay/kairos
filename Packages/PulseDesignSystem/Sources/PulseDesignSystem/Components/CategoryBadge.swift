import PulseDomain
import SwiftUI

/// Pastille de catégorie : un repère d'état et le nom, toujours écrit. Le repère est plein (bonne forme), à moitié plein
/// (fatigue) ou plein du signal (surmenage), lisible sans la couleur. `marker` : « Estimé », « En calibration ».
/// `onOpal` choisit les teintes lisibles sur la dalle tramée.
public struct CategoryBadge: View {
    private let category: RecoveryCategory
    private let marker: String?
    let onOpal: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(category: RecoveryCategory, marker: String? = nil, onOpal: Bool = false) {
        self.category = category
        self.marker = marker
        self.onOpal = onOpal
    }

    public var body: some View {
        let color = category.tone.color(onOpal: onOpal)
        HStack(spacing: 7) {
            StateMark(tone: category.tone, color: color)
            Text(text)
                .font(PulseFont.eyebrow)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(category.tone == .critical ? color : PulsePalette.text)
                // Le nom et son marqueur sont une valeur d'état : ils passent à la ligne au lieu d'être tronqués.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 9)
        .padding(.trailing, 11)
        .frame(minHeight: 26)
        .background { chrome(color: color) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    /// Une capsule sur une ligne ; un rectangle arrondi quand le texte passe à la ligne, pour que les coins n'écrasent pas le texte.
    @ViewBuilder
    private func chrome(color: Color) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            RoundedRectangle(cornerRadius: 13)
                .fill(PulsePalette.opal.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(color.opacity(0.32), lineWidth: 1))
        } else {
            Capsule()
                .fill(PulsePalette.opal.opacity(0.85))
                .overlay(Capsule().strokeBorder(color.opacity(0.32), lineWidth: 1))
        }
    }

    private var text: String {
        guard let marker else { return category.localizedName }
        return "\(category.localizedName) · \(marker)"
    }
}

/// Le repère d'état : un rond plein, à moitié plein ou plein du signal entouré d'un halo.
struct StateMark: View {
    let tone: CategoryTone
    let color: Color

    var body: some View {
        ZStack {
            Circle().strokeBorder(color, lineWidth: 1.2)
            switch tone {
            case .positive:
                Circle().fill(color)
            case .caution:
                Circle().trim(from: 0.25, to: 0.75).fill(color).rotationEffect(.degrees(-90))
            case .critical:
                Circle().fill(color).shadow(color: color, radius: 4)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
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

#Preview("Accessibilité 3") {
    VStack(alignment: .leading, spacing: 10) {
        CategoryBadge(category: .normal, marker: "En calibration (9 nuits)")
        CategoryBadge(category: .overreached, marker: "Estimé")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(PulsePalette.background)
    .dynamicTypeSize(.accessibility3)
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
