import PulseDomain
import SwiftUI

/// La jauge de récupération : un arc filaire rouge → ambre → vert, un repère au score, le score au centre. Pas d'aiguille.
/// La couleur du texte et de l'arc de fond suit le `foregroundStyle` de l'environnement (encre sur carte opale, blanc sur widget).
/// `cardColor` détoure le repère : le fond sur lequel la jauge est posée.
/// `animatesReveal` à `false` pose le repère d'emblée sur le score : WidgetKit rend une image fixe, sans `onAppear` ni animation.
public struct RecoveryGauge: View {
    public enum Style: Sendable {
        case large
        case compact

        var lineWidth: CGFloat {
            switch self {
            case .large: 3
            case .compact: 2.5
            }
        }

        var markerDiameter: CGFloat {
            switch self {
            case .large: 14
            case .compact: 9
            }
        }

        var idealWidth: CGFloat {
            switch self {
            case .large: 230
            case .compact: 116
            }
        }

        /// Le score (maquette : 64 pt sur 230 pt, 34 pt sur 116 pt) et « sur 100 » (13 pt sur 230 pt), en part de la largeur.
        var scoreScale: CGFloat {
            switch self {
            case .large: 0.28
            case .compact: 0.29
            }
        }

        var showsCaption: Bool { self == .large }
    }

    private let score: Double?
    private let category: RecoveryCategory?
    private let style: Style
    private let cardColor: Color
    private let animatesReveal: Bool

    @State private var shownScore: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        score: Double?,
        category: RecoveryCategory?,
        style: Style,
        cardColor: Color = PulsePalette.opal,
        animatesReveal: Bool = true
    ) {
        self.score = score
        self.category = category
        self.style = style
        self.cardColor = cardColor
        self.animatesReveal = animatesReveal
        _shownScore = State(initialValue: Self.initialScore(score: score, animatesReveal: animatesReveal))
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height * 4 / 3)
            ZStack(alignment: .top) {
                dial(side: side)
                    .frame(width: side, height: side)
                scoreLabel(side: side)
                    .frame(width: side, height: side * 0.75, alignment: .center)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: style.idealWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(score: score, category: category))
        .onAppear(perform: reveal)
        .onChange(of: score) { reveal() }
    }

    // MARK: Cadran

    private func dial(side: CGFloat) -> some View {
        ZStack {
            arc.stroke(.foreground, style: strokeStyle).opacity(0.12)
            arc.stroke(gradient, style: strokeStyle).opacity(score == nil ? 0.35 : 1)
            if score != nil {
                marker(side: side)
            }
        }
    }

    /// 240° de cercle à partir de 8 h : on tourne un tracé qui commence à 3 h, ce qui évite le sens de `addArc`.
    private var arc: some Shape {
        Circle()
            .inset(by: style.lineWidth / 2)
            .trim(from: 0, to: GaugeGeometry.sweepDegrees / 360)
            .rotation(.degrees(GaugeGeometry.startDegrees))
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
    }

    /// Rouge jusqu'au seuil de 40, ambre jusqu'à 65, vert au-delà, avec un court fondu autour des seuils.
    private var gradient: AngularGradient {
        let first = GaugeGeometry.thresholdFractions[0]
        let second = GaugeGeometry.thresholdFractions[1]
        let blend = 0.03
        return AngularGradient(
            stops: [
                .init(color: PulsePalette.bad, location: 0),
                .init(color: PulsePalette.bad, location: first - blend),
                .init(color: PulsePalette.warn, location: first + blend),
                .init(color: PulsePalette.warn, location: second - blend),
                .init(color: PulsePalette.ok, location: second + blend),
                .init(color: PulsePalette.ok, location: 1)
            ],
            center: .center,
            startAngle: .degrees(GaugeGeometry.startDegrees),
            endAngle: .degrees(GaugeGeometry.startDegrees + GaugeGeometry.sweepDegrees)
        )
    }

    /// Le repère part du bas gauche et tourne autour du centre : l'animation suit l'arc au lieu de couper en ligne droite.
    private func marker(side: CGFloat) -> some View {
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let origin = GaugeGeometry.point(for: 0, in: rect, lineWidth: style.lineWidth)
        return Circle()
            .fill(.foreground)
            .overlay(Circle().strokeBorder(cardColor, lineWidth: 2.5))
            .frame(width: style.markerDiameter, height: style.markerDiameter)
            .position(origin)
            .frame(width: side, height: side)
            .rotationEffect(.degrees(GaugeGeometry.sweepDegrees * GaugeGeometry.fraction(for: shownScore)))
    }

    // MARK: Score

    private func scoreLabel(side: CGFloat) -> some View {
        VStack(spacing: side * 0.026) {
            Text(verbatim: Self.roundedScore(score).map(String.init) ?? "—")
                .font(.system(size: side * style.scoreScale, weight: .heavy))
                .monospacedDigit()
                .tracking(-side * style.scoreScale * 0.05)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if style.showsCaption {
                Text(String(localized: "sur 100", bundle: .module))
                    .font(.system(size: max(11, side * 0.057), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, side * 0.18)
    }

    // MARK: Animation

    private func reveal() {
        let target = Self.initialScore(score: score, animatesReveal: false)
        if reduceMotion || !animatesReveal {
            shownScore = target
        } else {
            withAnimation(.easeOut(duration: 0.9)) { shownScore = target }
        }
    }

    /// Le score où le repère se trouve au premier rendu, borné à 0…100 : 0 si la jauge s'anime ensuite, sinon le score lui-même.
    nonisolated static func initialScore(score: Double?, animatesReveal: Bool) -> Double {
        guard !animatesReveal, let score, score.isFinite else { return 0 }
        return min(max(score, 0), 100)
    }

    // MARK: Accessibilité

    /// Le score entier, borné à 0…100 ; `nil` sans score ou s'il n'est pas fini.
    static func roundedScore(_ score: Double?) -> Int? {
        guard let score, score.isFinite else { return nil }
        return Int(min(max(score, 0), 100).rounded())
    }

    public static func accessibilityLabel(score: Double?, category: RecoveryCategory?) -> String {
        guard let value = roundedScore(score) else {
            return String(localized: "Récupération pas encore calculée", bundle: .module)
        }
        guard let category else {
            return String(localized: "Récupération \(value) sur 100", bundle: .module)
        }
        let name = category.localizedName.lowercased()
        return String(localized: "Récupération \(value) sur 100, \(name)", bundle: .module)
    }
}

private struct GaugePreviewRow: View {
    let style: RecoveryGauge.Style
    let cardColor: Color

    var body: some View {
        VStack(spacing: 18) {
            RecoveryGauge(score: 12, category: .overreached, style: style, cardColor: cardColor)
            RecoveryGauge(score: 58, category: .moderateFatigue, style: style, cardColor: cardColor)
            RecoveryGauge(score: 94, category: .optimal, style: style, cardColor: cardColor)
            RecoveryGauge(score: nil, category: nil, style: style, cardColor: cardColor)
        }
    }
}

#Preview("Large, sur carte opale") {
    ScrollView {
        OpalCard { GaugePreviewRow(style: .large, cardColor: PulsePalette.opal).frame(maxWidth: .infinity) }
            .padding()
    }
    .background(PulsePalette.background)
}

#Preview("Compact, sur fond sombre") {
    GaugePreviewRow(style: .compact, cardColor: PulsePalette.surface)
        .foregroundStyle(PulsePalette.text)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulsePalette.surface)
}
