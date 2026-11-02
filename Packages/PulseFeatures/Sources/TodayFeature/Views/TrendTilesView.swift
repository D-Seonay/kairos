import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Les trois tuiles de tendance sur 14 jours, sur deux colonnes ; une seule colonne aux tailles d'accessibilité.
struct TrendTilesView: View {
    let tiles: [TrendTile]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tiles, id: \.factor) { tile in
                TrendTileView(tile: tile)
            }
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: count)
    }
}

/// Le titre, la valeur et la courbe d'une tendance. VoiceOver lit une seule phrase, la courbe est muette.
private struct TrendTileView: View {
    let tile: TrendTile
    @Environment(\.pulseTheme) private var theme

    var body: some View {
        ObsidianCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(tile.title)
                    .font(.caption)
                    .foregroundStyle(PulsePalette.muted)
                Text(tile.valueText)
                    .font(.title2.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(PulsePalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Sparkline(values: tile.values, color: color)
                    .frame(height: 36)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tile.accessibilityLabel)
    }

    private var color: Color {
        switch tile.factor {
        case .hrv: Color(PulsePalette.accent(for: theme).accent)
        case .restingHeartRate: PulsePalette.warn
        case .sleep: PulsePalette.run
        }
    }
}

#Preview("Tuiles de tendance") {
    TrendTilesView(tiles: [
        TrendTile(factor: .hrv, title: "Variabilité, 14 jours", valueText: "44 ms",
                  values: [46, 48, 45, 47, 50, 49, 46, 48, 47, nil, 45, 44, 43, 44],
                  accessibilityLabel: "Variabilité, 14 jours, dernière valeur 44 ms"),
        TrendTile(factor: .restingHeartRate, title: "FC repos, 14 jours", valueText: "54 bpm",
                  values: [50, 51, 50, 52, 51, 50, 52, 53, 52, 54, 53, 54, 55, 54],
                  accessibilityLabel: "FC repos, 14 jours, dernière valeur 54 bpm"),
        TrendTile(factor: .sleep, title: "Sommeil, 14 jours", valueText: "7 h 12",
                  values: [440, 420, 450, 430, 400, 380, 440, 460, 430, 420, 410, 400, 390, 432],
                  accessibilityLabel: "Sommeil, 14 jours, moyenne 7 h 12")
    ])
    .padding()
    .background(PulsePalette.background)
}
