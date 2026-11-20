import PulseDomain
import SwiftUI

/// Pastille de catégorie : un repère d'état et le nom, toujours écrit. Le repère est plein (bonne forme), à moitié plein
/// (fatigue) ou plein du signal (surmenage), lisible sans la couleur. `marker` : « Estimé », « En calibration ».
/// `onOpal` choisit les teintes lisibles sur la dalle tramée.
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
        let color = category.tone.color(onOpal: onOpal)
        HStack(spacing: 7) {
            StateMark(tone: category.tone, color: color)
            Text(text)
                .font(PulseFont.eyebrow)
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(category.tone == .critical ? color : PulsePalette.text)
                .lineLimit(1)
        }
        .padding(.leading, 9)
        .padding(.trailing, 11)
        .frame(minHeight: 26)
        .background(PulsePalette.opal.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.32), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
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
