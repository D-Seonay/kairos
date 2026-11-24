import PulseDesignSystem
import PulseDomain
import SwiftUI

/// Les trois tuiles de tendance sur 14 jours, par rangées de deux ; une tuile seule sur sa rangée (la troisième) prend toute la
/// largeur, sans trou à côté. Une seule colonne dès les grandes tailles de texte (xxxLarge).
struct TrendTilesView: View {
    let tiles: [TrendTile]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rowStarts, id: \.self) { start in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(Array(tiles[start..<min(start + columnCount, tiles.count)]), id: \.factor) { tile in
                        TrendTileView(tile: tile)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var columnCount: Int {
        dynamicTypeSize >= .xxxLarge ? 1 : 2
    }

    /// L'indice de la première tuile de chaque rangée.
    private var rowStarts: [Int] {
        Array(stride(from: 0, to: tiles.count, by: columnCount))
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
                    .pulseEyebrow()
                    .fixedSize(horizontal: false, vertical: true)
                Text(tile.valueText)
                    .font(PulseFont.value(.title, weight: .regular))
                    .foregroundStyle(PulsePalette.text)
                    .fixedSize(horizontal: false, vertical: true)
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
        case .restingHeartRate: PulsePalette.text2
        case .sleep: PulsePalette.run
        }
    }
}

private enum TrendTilesPreview {
    static let tiles = [
        TrendTile(factor: .hrv, title: "Variabilité, 14 jours", valueText: "44 ms",
                  values: [46, 48, 45, 47, 50, 49, 46, 48, 47, nil, 45, 44, 43, 44],
                  accessibilityLabel: "Variabilité, 14 jours, dernière valeur 44 millisecondes, tendance stable"),
        TrendTile(factor: .restingHeartRate, title: "FC repos, 14 jours", valueText: "54 bpm",
                  values: [50, 51, 50, 52, 51, 50, 52, 53, 52, 54, 53, 54, 55, 54],
                  accessibilityLabel: "Fréquence cardiaque au repos, 14 jours, dernière valeur 54 battements par minute, "
                      + "tendance en hausse"),
        TrendTile(factor: .sleep, title: "Sommeil, 14 jours", valueText: "7 h 12",
                  values: [440, 420, 450, 430, 400, 380, 440, 460, 430, 420, 410, 400, 390, 432],
                  accessibilityLabel: "Sommeil, 14 jours, moyenne 7 heures 12 minutes, tendance stable")
    ]
}

#Preview("Tuiles de tendance") {
    TrendTilesView(tiles: TrendTilesPreview.tiles)
        .padding()
        .background(PulsePalette.background)
}

#Preview("Tuiles de tendance, accessibilité 3") {
    TrendTilesView(tiles: TrendTilesPreview.tiles)
        .padding()
        .background(PulsePalette.background)
        .dynamicTypeSize(.accessibility3)
}
