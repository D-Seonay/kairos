import SwiftUI

/// La carte de partage, telle qu'elle part en image : un tirage « Argentique » sur noir. L'étiquette mono et la marque PULSE en
/// haut, le titre et la date, le dessin (carte musculaire ou tracé) sur une trame de points, les chiffres en grand et fins, les
/// records en champagne, puis « Suivi avec Pulse ». Toujours sombre, quelle que soit l'apparence : ses couleurs sont fixes.
/// Avec `photo`, l'image remplit la carte et prend la place du dessin. Elle se dessine à la taille de `format.size` ;
/// `ShareCardRenderer` en tire l'image. Avec `isSticker`, la carte perd son fond : le contenu seul, à l'encre ombrée, à la
/// hauteur qu'il lui faut (l'image sans fond, à coller sur sa propre photo).
public struct ShareCardView: View {
    private let content: ShareCardContent
    private let format: ShareCardFormat
    private let photo: CGImage?
    private let isSticker: Bool

    private static let paper = Color(PulsePalette.pageRGBA)
    private static let ink = Color(PulsePalette.textRGBA)
    private static let ink2 = Color(PulsePalette.text2RGBA)
    private static let muted = Color(PulsePalette.mutedRGBA)
    private static let line = Color(PulsePalette.lineRGBA)
    private static let gold = Color(PulsePalette.goldRGBA)

    public init(content: ShareCardContent, format: ShareCardFormat, photo: CGImage? = nil, isSticker: Bool = false) {
        self.content = content
        self.format = format
        self.photo = photo
        self.isSticker = isSticker
    }

    private var isStory: Bool { format == .story }

    // Sans fond, la photo dessous peut être claire : le gris ne s'y lirait pas, tout passe en blanc et les chiffres s'épaississent.
    private var secondaryInk: Color { isSticker ? Self.ink.opacity(0.9) : Self.ink2 }
    private var labelInk: Color { isSticker ? Self.ink.opacity(0.85) : Self.muted }
    private var numberWeight: Font.Weight { isSticker ? .light : .thin }

    public var body: some View {
        Group {
            if isSticker { sticker } else { card }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.caption)
        .accessibilityAddTraits(.isImage)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            titleBlock
                .padding(.top, isStory ? 28 : 18)
            visual
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, isStory ? 20 : 12)
            metrics
            if !content.highlights.isEmpty {
                highlights
                    .padding(.top, 16)
            }
            footer
                .padding(.top, isStory ? 24 : 16)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, isStory ? 36 : 26)
        .frame(width: format.size.width, height: format.size.height)
        .background { background }
    }

    /// Le contenu sans fond : le dessin à une hauteur fixe, le reste à sa taille, et une ombre (un liseré serré, puis un halo)
    /// qui garde l'encre blanche lisible sur une photo claire. Pas de pied : la marque PULSE en haut suffit à un sticker. Le
    /// groupe est composé avant l'ombre, pour qu'elle ne se double pas là où l'encre se croise.
    private var sticker: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            titleBlock
                .padding(.top, 28)
            stickerDrawing
            metrics
            if !content.highlights.isEmpty {
                highlights
                    .padding(.top, 16)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(width: format.size.width)
        .fixedSize(horizontal: false, vertical: true)
        .compositingGroup()
        .shadow(color: .black.opacity(0.6), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.35), radius: 8)
    }

    @ViewBuilder
    private var stickerDrawing: some View {
        if let height = Self.stickerDrawingHeight(content.visual) {
            drawing
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .padding(.vertical, 20)
        } else if content.visual.isHero {
            drawing
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 20)
        } else {
            Spacer().frame(height: 20)
        }
    }

    /// La hauteur du dessin sur l'image sans fond ; `nil` pour un dessin qui prend sa propre hauteur (le chiffre d'un record)
    /// ou pour l'absence de dessin.
    static func stickerDrawingHeight(_ visual: ShareCardContent.Visual) -> CGFloat? {
        switch visual {
        case .muscles: 200
        case .route: 200
        case .hypnogram: 160
        case .hero, .none: nil
        }
    }

    // MARK: Parties

    @ViewBuilder
    private var background: some View {
        if let photo {
            SharePhotoBackground(photo: photo, size: format.size, paper: Self.paper, ink: Self.ink,
                                 isVeiled: content.visual.isHero)
        } else {
            halftoneBackground
        }
    }

    private var halftoneBackground: some View {
        ZStack {
            Self.paper
            // Une lumière tramée derrière le dessin, qui s'éteint vers les bords et laisse les chiffres sur du noir.
            HalftoneField(spacing: 6, color: Self.ink.opacity(0.26)) { point in
                0.9 * Halftone.glow(at: point, center: CGPoint(x: 0.7, y: 0.34), spread: 0.24)
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(content.eyebrow)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(secondaryInk)
            Spacer(minLength: 12)
            wordmark
        }
    }

    /// La marque : PULSE en capitales mono très espacées, précédée d'un point d'encre.
    private var wordmark: some View {
        HStack(spacing: 6) {
            Circle().fill(Self.ink).frame(width: 6, height: 6)
            Text(verbatim: "PULSE")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Self.ink)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.title)
                .font(.system(size: isStory ? 34 : 28, weight: .bold))
                .foregroundStyle(Self.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(content.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var visual: some View {
        // Sur une photo, le dessin s'efface : la photo est le sujet. Le chiffre d'un record reste, il est la carte.
        if photo != nil, !content.visual.isHero {
            Color.clear
        } else {
            drawing
        }
    }

    @ViewBuilder
    private var drawing: some View {
        switch content.visual {
        case .none:
            Color.clear
        case .hero(let value, let label):
            ShareHeroView(value: value, label: label, ink: Self.ink, muted: labelInk, isStory: isStory, weight: numberWeight)
        case .hypnogram(let hypnogram):
            ShareHypnogramView(hypnogram: hypnogram, ink: Self.ink, muted: labelInk, line: Self.line)
                .frame(maxHeight: .infinity, alignment: .center)
        case .muscles(let levels):
            GeometryReader { proxy in
                MuscleMapView(levels: levels, label: "", height: max(0, proxy.size.height))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        case .route(let points):
            ShareRouteShape(points: points)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .overlay { ShareRouteEnds(points: points, color: Self.ink, paper: Self.paper) }
                .padding(8)
        }
    }

    private var metrics: some View {
        let rows = stride(from: 0, to: content.metrics.count, by: 2).map { Array(content.metrics[$0..<min($0 + 2, content.metrics.count)]) }
        return VStack(alignment: .leading, spacing: isStory ? 18 : 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 16) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, metric in
                        metricView(metric)
                    }
                    if row.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func metricView(_ metric: ShareCardMetric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.value)
                .font(.system(size: isStory ? 46 : 38, weight: numberWeight).monospacedDigit())
                .foregroundStyle(Self.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(metric.label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(labelInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(content.highlights.prefix(isStory ? 3 : 1).enumerated()), id: \.offset) { _, text in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Self.gold)
            }
            // La publication, plus basse, garde sa place au dessin : le reste des records n'y est pas compté.
            if isStory, content.highlights.count > 3 {
                Text(ShareCardText.moreRecords(content.highlights.count - 3))
                    .font(.system(size: 12))
                    .foregroundStyle(Self.gold.opacity(0.7))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Self.line).frame(height: 1)
            HStack {
                Text(String(localized: "Suivi avec Pulse", bundle: .module))
                Spacer()
                Text(verbatim: "pulserecovery.app")
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(labelInk)
        }
    }
}

extension ShareCardContent.Visual {
    var isHero: Bool {
        if case .hero = self { return true }
        return false
    }
}

/// Le tracé de `ShareRoute.normalized`, posé au centre du cadre sans le déformer.
struct ShareRouteShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let placed = Self.place(points, in: rect)
        guard let first = placed.first else { return path }
        path.move(to: first)
        for point in placed.dropFirst() { path.addLine(to: point) }
        return path
    }

    /// Le carré unité ramené au plus grand carré centré dans `rect`.
    static func place(_ points: [CGPoint], in rect: CGRect) -> [CGPoint] {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        return points.map { CGPoint(x: origin.x + $0.x * side, y: origin.y + $0.y * side) }
    }
}

/// Le départ (un rond plein) et l'arrivée (un rond cerné) du tracé.
private struct ShareRouteEnds: View {
    let points: [CGPoint]
    let color: Color
    let paper: Color

    var body: some View {
        GeometryReader { proxy in
            let placed = ShareRouteShape.place(points, in: CGRect(origin: .zero, size: proxy.size))
            if let start = placed.first, let end = placed.last {
                Circle().fill(color).frame(width: 10, height: 10).position(start)
                Circle().fill(paper).overlay(Circle().strokeBorder(color, lineWidth: 2.5)).frame(width: 12, height: 12).position(end)
            }
        }
    }
}

/// Les textes de la carte.
enum ShareCardText {
    /// « + 2 autres records ».
    static func moreRecords(_ count: Int) -> String {
        count == 1 ? String(localized: "+ 1 autre record", bundle: .module)
            : String(localized: "+ \(count) autres records", bundle: .module)
    }
}

#if DEBUG
extension ShareCardContent {
    static let previewSession = ShareCardContent(
        eyebrow: "Séance", title: "Push", subtitle: "mardi 24 novembre",
        metrics: [ShareCardMetric(value: "1 h 05", label: "Durée", caption: "1 h 05"),
                  ShareCardMetric(value: "4 250", label: "kg soulevés", caption: "4 250 kg"),
                  ShareCardMetric(value: "18", label: "Séries", caption: "18 séries"),
                  ShareCardMetric(value: "2", label: "Records", caption: "2 records")],
        highlights: ["Développé couché à la barre : 82,5 kg", "Dips : 12 répétitions"],
        visual: .muscles([.chest: 4, .triceps: 3, .frontDeltoid: 2]))

    static let previewRun = ShareCardContent(
        eyebrow: "Course", title: "Footing", subtitle: "dimanche 22 novembre",
        metrics: [ShareCardMetric(value: "8,42 km", label: "Distance"), ShareCardMetric(value: "46:10", label: "En mouvement"),
                  ShareCardMetric(value: "5'29\"/km", label: "Allure")],
        visual: .route(ShareRoute.normalized(
            latitudes: (0..<60).map { 48.85 + 0.01 * sin(Double($0) / 9.5) },
            longitudes: (0..<60).map { 2.35 + 0.014 * cos(Double($0) / 9.5) + Double($0) * 0.0002 })))
}

extension ShareCardContent {
    static let previewRecord = ShareCardContent(
        eyebrow: "Record", title: "Développé couché à la barre", subtitle: "mardi 24 novembre",
        metrics: [ShareCardMetric(value: "85 × 5", label: "Série"), ShareCardMetric(value: "+2,5 kg", label: "Progression")],
        visual: .hero(value: "96 kg", label: "1RM estimé"))

    static let previewNight = ShareCardContent(
        eyebrow: "Nuit", title: "Nuit du 23 au 24 nov.", subtitle: "Endormi à 23:10 · Réveillé à 06:50",
        metrics: [ShareCardMetric(value: "7 h 12", label: "Endormi"), ShareCardMetric(value: "1 h 20", label: "Profond"),
                  ShareCardMetric(value: "1 h 45", label: "Paradoxal"), ShareCardMetric(value: "1", label: "Réveil")],
        visual: .hypnogram(ShareCardHypnogram(
            rows: ["Éveil", "Paradoxal", "Léger", "Profond"],
            bars: [.init(row: 2, start: 0, end: 0.08), .init(row: 3, start: 0.08, end: 0.22), .init(row: 2, start: 0.22, end: 0.38),
                   .init(row: 1, start: 0.38, end: 0.46), .init(row: 0, start: 0.46, end: 0.48), .init(row: 2, start: 0.48, end: 0.62),
                   .init(row: 3, start: 0.62, end: 0.7), .init(row: 2, start: 0.7, end: 0.84), .init(row: 1, start: 0.84, end: 1)])))
}

#Preview("Record, story") {
    ShareCardView(content: .previewRecord, format: .story)
}

#Preview("Nuit, story") {
    ShareCardView(content: .previewNight, format: .story)
}

#Preview("Séance, story") {
    ShareCardView(content: .previewSession, format: .story)
}

#Preview("Sticker, séance") {
    ShareCardView(content: .previewSession, format: .story, isSticker: true)
        .background(Color.gray)
}

#Preview("Course, publication") {
    ShareCardView(content: .previewRun, format: .post)
}
#endif
