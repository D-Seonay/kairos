import PulseDomain
import SwiftUI

/// Curseur force / endurance de l'écran `objectifs`, avec le libellé « 60 / 40 ». 0 = force, 1 = endurance.
public struct FocusSlider: View {
    @Binding private var focus: Double
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(focus: Binding<Double>) {
        _focus = focus
    }

    /// Le curseur avance par dixièmes ; ce qu'il écrit dans le profil est arrondi au dixième exact.
    private var snappedFocus: Binding<Double> {
        Binding(get: { focus }, set: { focus = FocusSplit.snapped($0) })
    }

    public var body: some View {
        VStack(spacing: 6) {
            captions
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(PulsePalette.text)

            Slider(value: snappedFocus, in: 0...1, step: 0.1)
                .tint(Color(PulsePalette.accent(for: theme).accent))
                .accessibilityLabel(String(localized: "Équilibre force endurance", bundle: .module))
                .accessibilityValue(FocusSplit.label(focus: focus))

            extremes
                .font(.footnote)
                .foregroundStyle(PulsePalette.text2)
                .accessibilityHidden(true)
        }
    }

    /// « Force | 60 / 40 | Endurance » : sur une rangée, en colonne aux tailles d'accessibilité.
    @ViewBuilder
    private var captions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                force
                ratio
                endurance
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                force
                Spacer()
                ratio
                Spacer()
                endurance
            }
        }
    }

    /// « 100 % musculation | Hybride | 100 % running » : même règle.
    @ViewBuilder
    private var extremes: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "100 % musculation", bundle: .module))
                Text(String(localized: "Hybride", bundle: .module))
                Text(String(localized: "100 % running", bundle: .module))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text(String(localized: "100 % musculation", bundle: .module))
                Spacer()
                Text(String(localized: "Hybride", bundle: .module))
                Spacer()
                Text(String(localized: "100 % running", bundle: .module))
            }
        }
    }

    private var force: some View {
        Label(String(localized: "Force", bundle: .module), systemImage: "dumbbell.fill")
    }

    private var ratio: some View {
        Text(FocusSplit.label(focus: focus))
            .monospacedDigit()
            .accessibilityHidden(true)
    }

    private var endurance: some View {
        Label(String(localized: "Endurance", bundle: .module), systemImage: "figure.run")
            .labelStyle(TrailingIconLabelStyle())
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

private struct FocusSliderPreview: View {
    @State private var focus = 0.4

    var body: some View {
        FocusSlider(focus: $focus)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PulsePalette.background)
    }
}

#Preview {
    FocusSliderPreview()
}

#Preview("Accessibilité 3") {
    FocusSliderPreview()
        .dynamicTypeSize(.accessibility3)
}
