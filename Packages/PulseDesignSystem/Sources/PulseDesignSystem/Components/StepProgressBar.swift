import PulseDomain
import SwiftUI

/// Barre d'étapes de l'onboarding : `current` segments blancs sur `total`, l'étape en cours plus longue (`.steps` de la maquette).
public struct StepProgressBar: View {
    private let current: Int
    private let total: Int
    @Environment(\.pulseTheme) private var theme

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        let palette = PulsePalette.accent(for: theme)
        HStack(spacing: 6) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index < current ? Color(palette.accent) : PulsePalette.ink.opacity(0.12))
                    .frame(maxWidth: index == current - 1 ? .infinity : 36)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Étape \(current) sur \(total)", bundle: .module))
    }
}

#Preview {
    VStack(spacing: 16) {
        StepProgressBar(current: 1, total: 4)
        StepProgressBar(current: 3, total: 4)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.background)
}
