import SwiftUI

/// Le chiffre d'un record, en très grand et fin, sous son étiquette mono.
struct ShareHeroView: View {
    let value: String
    let label: String
    let ink: Color
    let muted: Color
    let isStory: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: isStory ? 26 : 20))
                .foregroundStyle(Color(PulsePalette.goldRGBA))
            Text(value)
                .font(.system(size: isStory ? 104 : 80, weight: .thin).monospacedDigit())
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// L'hypnogramme de la carte, comme sur l'écran Nuit : les noms des rangées à gauche, un filet par rangée, chaque tranche en
/// barre fine sur sa rangée, et un trait vertical qui relie une tranche à la suivante.
struct ShareHypnogramView: View {
    let hypnogram: ShareCardHypnogram
    let ink: Color
    let muted: Color
    let line: Color

    private static let labelWidth: CGFloat = 78
    private static let barHeight: CGFloat = 9

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(hypnogram.rows.enumerated()), id: \.offset) { _, name in
                    Text(name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .frame(width: Self.labelWidth)
            Canvas { context, size in
                draw(in: &context, size: size)
            }
        }
        .frame(maxHeight: 200)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let count = hypnogram.rows.count
        guard count > 0, size.width > 0 else { return }
        let rowHeight = size.height / CGFloat(count)
        func centerY(_ row: Int) -> CGFloat { (CGFloat(row) + 0.5) * rowHeight }
        for row in 0..<count {
            context.fill(Path(CGRect(x: 0, y: centerY(row) - 0.5, width: size.width, height: 1)), with: .color(line))
        }
        let bars = hypnogram.bars.sorted { $0.start < $1.start }
        var links = Path()
        for (previous, next) in zip(bars, bars.dropFirst()) where previous.row != next.row {
            let x = next.start * size.width
            links.move(to: CGPoint(x: x, y: centerY(previous.row)))
            links.addLine(to: CGPoint(x: x, y: centerY(next.row)))
        }
        context.stroke(links, with: .color(ink.opacity(0.35)), lineWidth: 1.5)
        for bar in bars {
            let rect = CGRect(x: bar.start * size.width, y: centerY(bar.row) - Self.barHeight / 2,
                              width: max(2, (bar.end - bar.start) * size.width), height: Self.barHeight)
            let opacity = Self.opacity(row: bar.row, of: count)
            context.fill(Path(roundedRect: rect, cornerRadius: Self.barHeight / 2), with: .color(ink.opacity(opacity)))
        }
    }

    /// Du plus léger (l'éveil, en haut) au plus encré (le profond, en bas) : la profondeur se lit en contraste.
    static func opacity(row: Int, of count: Int) -> Double {
        guard count > 1 else { return 1 }
        return 0.45 + 0.55 * Double(row) / Double(count - 1)
    }
}

/// Le fond photo : l'image en plein cadre, assombrie en haut et surtout en bas pour que le texte blanc reste lisible, et une
/// trame légère sur la partie sombre, la signature de la carte.
struct SharePhotoBackground: View {
    let photo: CGImage
    let size: CGSize
    let paper: Color
    let ink: Color
    /// Un voile égal sur toute la photo, quand un texte se pose en son milieu (le chiffre d'un record).
    var isVeiled = false

    var body: some View {
        ZStack {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
            if isVeiled { paper.opacity(0.5) }
            LinearGradient(stops: [.init(color: paper.opacity(0.6), location: 0),
                                   .init(color: paper.opacity(0), location: 0.28),
                                   .init(color: paper.opacity(0.1), location: 0.38),
                                   .init(color: paper.opacity(0.8), location: 0.56),
                                   .init(color: paper.opacity(0.94), location: 0.75),
                                   .init(color: paper.opacity(0.97), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            HalftoneField(spacing: 6, color: ink.opacity(0.12)) { point in
                max(0, min(1, (Double(point.y) - 0.55) * 2.2))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
