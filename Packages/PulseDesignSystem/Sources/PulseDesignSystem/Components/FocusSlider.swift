import PulseDomain
import SwiftUI

/// Curseur force / endurance de l'écran `objectifs`, avec le libellé « 60 / 40 ». 0 = force, 1 = endurance.
public struct FocusSlider: View {
    @Binding private var focus: Double
    @Environment(\.pulseTheme) private var theme

    public init(focus: Binding<Double>) {
        _focus = focus
    }

    /// Le curseur avance par dixièmes ; ce qu'il écrit dans le profil est arrondi au dixième exact.
    private var snappedFocus: Binding<Double> {
        Binding(get: { focus }, set: { focus = FocusSplit.snapped($0) })
    }

    public var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(String(localized: "Force", bundle: .module), systemImage: "dumbbell.fill")
                Spacer()
                Text(FocusSplit.label(focus: focus))
                    .monospacedDigit()
                    .accessibilityHidden(true)
                Spacer()
                Label(String(localized: "Endurance", bundle: .module), systemImage: "figure.run")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(PulsePalette.text)

            Slider(value: snappedFocus, in: 0...1, step: 0.1)
                .tint(Color(PulsePalette.accent(for: theme).accent))
                .accessibilityLabel(String(localized: "Équilibre force endurance", bundle: .module))
                .accessibilityValue(FocusSplit.label(focus: focus))

            HStack {
                Text(String(localized: "100 % musculation", bundle: .module))
                Spacer()
                Text(String(localized: "Hybride", bundle: .module))
                Spacer()
                Text(String(localized: "100 % running", bundle: .module))
            }
            .font(.footnote)
            .foregroundStyle(PulsePalette.text2)
            .accessibilityHidden(true)
        }
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
