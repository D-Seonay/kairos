import SwiftUI

/// Carte opale : fond blanc, encre sombre. Pour les métriques clés (le score).
public struct OpalCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(PulsePalette.opalInk)
            .padding(PulseMetrics.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PulsePalette.opal, in: shape)
            .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous)
    }
}

/// Carte obsidienne : verre iOS 26 teinté sur `surface`, bord `line`. Pour tout le reste.
public struct ObsidianCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(PulsePalette.text)
            .padding(PulseMetrics.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(PulsePalette.surface.opacity(0.72)), in: shape)
            .overlay(shape.strokeBorder(PulsePalette.line))
            .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PulseMetrics.radius, style: .continuous)
    }
}

#Preview {
    VStack(spacing: 10) {
        OpalCard {
            Text("Carte opale").font(.headline)
            Text("sur 100").font(.footnote).foregroundStyle(PulsePalette.opalMuted)
        }
        ObsidianCard {
            Text("Carte obsidienne").font(.headline)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PulsePalette.background)
}
