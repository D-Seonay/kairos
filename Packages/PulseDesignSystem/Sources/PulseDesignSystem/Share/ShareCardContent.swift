import CoreGraphics
import Foundation

/// Ce que montre la carte de partage d'une séance ou d'une course : l'étiquette (« SÉANCE », « COURSE »), le titre, la date, au
/// plus quatre chiffres, les records battus, et un dessin (la carte musculaire ou le tracé). `caption` est le texte envoyé avec
/// l'image (Messages, WhatsApp…) et lu par VoiceOver : le titre, les chiffres, puis le lien vers Pulse.
public struct ShareCardContent: Equatable, Sendable {
    /// Le dessin au centre de la carte.
    public enum Visual: Equatable, Sendable {
        case none
        /// Les niveaux de la carte musculaire, de 1 à 4.
        case muscles([MuscleMapRegion: Int])
        /// Le tracé ramené dans le carré unité (voir `ShareRoute.normalized`).
        case route([CGPoint])
        /// Un chiffre en très grand, seul au centre : la valeur d'un record (« 96 kg ») et ce qu'elle mesure (« 1RM estimé »).
        case hero(value: String, label: String)
        /// L'hypnogramme d'une nuit, en barres blanches sur ses rangées.
        case hypnogram(ShareCardHypnogram)
    }

    /// La page de Pulse sur l'App Store, ajoutée au texte partagé.
    public static let appStoreLink = "https://apps.apple.com/fr/app/pulse-r%C3%A9cup%C3%A9ration-muscu/id6829265826"

    /// Le nombre de chiffres que la carte affiche, sur deux colonnes.
    public static let maxMetrics = 4

    public var eyebrow: String
    public var title: String
    public var subtitle: String
    public var metrics: [ShareCardMetric]
    public var highlights: [String]
    public var visual: Visual

    public init(eyebrow: String, title: String, subtitle: String, metrics: [ShareCardMetric], highlights: [String] = [],
                visual: Visual = .none) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.metrics = Array(metrics.prefix(Self.maxMetrics))
        self.highlights = highlights
        self.visual = visual
    }

    /// « Push · 1 h 05 · 12 séries · 4 250 kg », puis « Suivi avec Pulse : https://apps.apple.com/… » à la ligne. Le chiffre d'un
    /// record suit le titre : « Développé couché · 96 kg · 85 kg × 5 ».
    public var caption: String {
        var hero: [String] = []
        if case .hero(let value, _) = visual { hero = [value] }
        let head = ([title] + hero + metrics.map(\.caption)).filter { !$0.isEmpty }.joined(separator: " · ")
        let link = String(localized: "Suivi avec Pulse : \(Self.appStoreLink)", bundle: .module)
        return head + "\n" + link
    }

    /// Le nom du fichier partagé : « Pulse - Push.png », sans les caractères qu'un nom de fichier refuse.
    public var fileName: String {
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Pulse.png" : "Pulse - \(cleaned).png"
    }
}

/// Un chiffre de la carte : « 4 250 » au-dessus de « KG SOULEVÉS ». `caption` est sa forme dans le texte partagé : « 4 250 kg ».
public struct ShareCardMetric: Equatable, Sendable {
    public var value: String
    public var label: String
    public var caption: String

    public init(value: String, label: String, caption: String? = nil) {
        self.value = value
        self.label = label
        self.caption = caption ?? "\(value) \(label)"
    }
}

/// Le format de l'image : la story (9:16) ou la publication (4:5), toutes deux à 1 080 pixels de large.
public enum ShareCardFormat: String, CaseIterable, Identifiable, Sendable {
    case story
    case post

    public var id: String { rawValue }

    /// La taille du dessin en points ; l'image est tirée à `ShareCardFormat.scale`.
    public var size: CGSize {
        switch self {
        case .story: CGSize(width: 360, height: 640)
        case .post: CGSize(width: 360, height: 450)
        }
    }

    /// 360 pt × 3 = 1 080 pixels, la largeur qu'attendent Instagram, TikTok et Snapchat.
    public static let scale: CGFloat = 3

    public var title: String {
        switch self {
        case .story: String(localized: "Story", bundle: .module)
        case .post: String(localized: "Publication", bundle: .module)
        }
    }
}

/// Le tracé d'une course ramené au carré unité, pour le dessiner sans carte : une projection plate corrigée de la latitude (un
/// degré de longitude rétrécit vers les pôles), centrée, aux proportions gardées, et allégée à `maxPoints` points.
public enum ShareRoute {
    public static let maxPoints = 400

    /// Les points dans 0…1 sur chaque axe, le nord en haut. Vide sous deux points ou si tous se confondent.
    public static func normalized(latitudes: [Double], longitudes: [Double], maxPoints: Int = maxPoints) -> [CGPoint] {
        let count = min(latitudes.count, longitudes.count)
        guard count >= 2, maxPoints >= 2 else { return [] }
        let meanLatitude = latitudes.prefix(count).reduce(0, +) / Double(count)
        let squeeze = cos(meanLatitude * .pi / 180)
        let step = max(1, Int((Double(count) / Double(maxPoints)).rounded(.up)))
        var indices = Array(stride(from: 0, to: count, by: step))
        if indices.last != count - 1 { indices.append(count - 1) }
        let raw = indices.map { CGPoint(x: longitudes[$0] * squeeze, y: -latitudes[$0]) }
        let xs = raw.map(\.x), ys = raw.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return [] }
        let span = max(maxX - minX, maxY - minY)
        guard span > 0 else { return [] }
        let offsetX = (span - (maxX - minX)) / 2
        let offsetY = (span - (maxY - minY)) / 2
        return raw.map { CGPoint(x: ($0.x - minX + offsetX) / span, y: ($0.y - minY + offsetY) / span) }
    }
}

/// L'hypnogramme de la carte : les noms des rangées de haut en bas (« Éveil », « Paradoxal », « Léger », « Profond ») et les
/// tranches de la nuit, chacune sur sa rangée, entre 0 (l'endormissement) et 1 (le réveil).
public struct ShareCardHypnogram: Equatable, Sendable {
    public struct Bar: Equatable, Sendable {
        public var row: Int
        public var start: Double
        public var end: Double

        public init(row: Int, start: Double, end: Double) {
            self.row = row
            self.start = start
            self.end = end
        }
    }

    public var rows: [String]
    public var bars: [Bar]

    public init(rows: [String], bars: [Bar]) {
        self.rows = rows
        self.bars = bars
    }

    /// Une tranche datée de la nuit, sur sa rangée ; `nil` pour une phase que l'hypnogramme ne montre pas.
    public struct Segment: Sendable {
        public var row: Int?
        public var start: Date
        public var end: Date

        public init(row: Int?, start: Date, end: Date) {
            self.row = row
            self.start = start
            self.end = end
        }
    }

    /// Les tranches ramenées entre `from` et `to` ; une tranche hors de la nuit, vide ou sur une rangée inconnue est écartée,
    /// une tranche qui déborde est coupée.
    public static func bars(of segments: [Segment], from: Date, to: Date, rowCount: Int) -> [Bar] {
        let span = to.timeIntervalSince(from)
        guard span > 0 else { return [] }
        return segments.compactMap { segment in
            guard let row = segment.row, (0..<rowCount).contains(row) else { return nil }
            let start = max(0, segment.start.timeIntervalSince(from) / span)
            let end = min(1, segment.end.timeIntervalSince(from) / span)
            return end > start ? Bar(row: row, start: start, end: end) : nil
        }
    }
}

/// Une photo proposée en fond de carte : sa vignette pour le choix, et l'image entière, lue seulement si on la choisit.
public struct ShareCardPhoto: Identifiable, Sendable {
    public let id: UUID
    public let thumbnail: Data
    public let load: @Sendable () async -> Data?

    public init(id: UUID, thumbnail: Data, load: @escaping @Sendable () async -> Data?) {
        self.id = id
        self.thumbnail = thumbnail
        self.load = load
    }
}
