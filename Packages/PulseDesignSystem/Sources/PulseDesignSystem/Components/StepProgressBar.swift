import PulseDomain
import SwiftUI

/// Barre d'étapes de l'onboarding : `current` segments accent sur `total` (`.steps` de la maquette).
public struct StepProgressBar: View {
    private let current: Int
    private let total: Int
    @Environment(\.pulseTheme) private var theme

    public init(current: Int, total: Int) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        HStack(spacing: 6) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index < current ? accent : PulsePalette.surface2)
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
