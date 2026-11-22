import PulseContent
import PulseDesignSystem
import SwiftUI

/// Une barre des muscles travaillés du récap : le groupe, la barre et le nombre de séries. À une taille d'accessibilité, le nom
/// et la valeur passent au-dessus de la barre : le nom ne se tronque jamais.
struct RecapGroupBar: View {
    let group: MuscleGroup
    let count: Int
    let fraction: Double
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var nameWidth: CGFloat = 96

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        name.fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        value
                    }
                    bar
                }
            } else {
                HStack(spacing: 10) {
                    name.frame(width: nameWidth, alignment: .leading)
                    bar
                    value.frame(minWidth: 24, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(group.localizedName)
        .accessibilityValue(RecapView.setsText(count))
    }

    private var name: some View {
        Text(group.localizedName)
            .font(.subheadline)
            .foregroundStyle(PulsePalette.text)
    }

    private var value: some View {
        Text("\(count)")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(PulsePalette.text)
    }

    private var bar: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(PulsePalette.surface2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color(PulsePalette.accent(for: theme).accent))
                        .frame(width: proxy.size.width * fraction)
                }
        }
        .frame(height: 8)
    }
}
