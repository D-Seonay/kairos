import PulseDomain
import SwiftUI

/// La carte musculaire : face et dos côte à côte. Corps en `muscleBody`, régions de base éteintes en `muscleOff`,
/// niveaux 1 à 4 en mélange accent / `muscleOff`. Les régions en surimpression ne sont dessinées que si elles sont allumées.
public struct MuscleMapView: View {
    private let levels: [MuscleMapRegion: Int]
    private let label: String
    private let height: CGFloat
    private let artwork = MuscleMapArtwork.bundled

    @Environment(\.pulseTheme) private var theme

    public init(levels: [MuscleMapRegion: Int], label: String, height: CGFloat) {
        self.levels = levels
        self.label = label
        self.height = height
    }

    public var body: some View {
        HStack(spacing: height * 0.08) {
            silhouette(.front)
            silhouette(.back)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func silhouette(_ side: MuscleMapSide) -> some View {
        let box = artwork.viewBox(side)
        let accent = PulsePalette.accent(for: theme).accent
        return Canvas { context, size in
            draw(side, accent: accent, in: &context, size: size)
        }
        .aspectRatio(box.width / max(box.height, 1), contentMode: .fit)
        .frame(height: height)
    }

    private func draw(_ side: MuscleMapSide, accent: PulseRGBA, in context: inout GraphicsContext, size: CGSize) {
        let box = artwork.viewBox(side)
        guard box.width > 0, box.height > 0 else { return }
        let scale = min(size.width / box.width, size.height / box.height)
        let transform = CGAffineTransform(translationX: -box.minX, y: -box.minY).scaledBy(x: scale, y: scale)

        for layer in artwork.layers(side) {
            guard let color = fill(for: layer.region, accent: accent) else { continue }
            for path in layer.paths {
                context.fill(path.applying(transform), with: .color(color))
            }
        }
    }

    /// Le corps en `muscleBody`, une région allumée à son niveau, une région de base éteinte en `muscleOff`,
    /// une région en surimpression éteinte : rien.
    private func fill(for region: MuscleMapRegion?, accent: PulseRGBA) -> Color? {
        guard let region else { return PulsePalette.muscleBody }
        let level = levels[region] ?? 0
        if level > 0 { return Color(MuscleIntensity.color(level: level, accent: accent)) }
        return region.isOverlay ? nil : PulsePalette.muscleOff
    }
}

#Preview("Séance Push") {
    MuscleMapView(levels: [.chest: 4, .triceps: 3, .frontDeltoid: 2], label: "Pectoraux, triceps, épaules", height: 320)
        .padding()
        .background(PulsePalette.background)
}
