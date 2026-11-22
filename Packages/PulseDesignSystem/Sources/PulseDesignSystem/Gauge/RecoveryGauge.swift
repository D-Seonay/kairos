import PulseDomain
import SwiftUI

/// La jauge de récupération : la lunette d'un chronomètre. Des graduations sur 240° s'allument jusqu'au score, de plus en plus
/// claires, comme une traînée de lumière ; elles prennent le gris de la fatigue ou le signal du surmenage. Une aiguille courte
/// marque le score, le score s'affiche au centre en grands chiffres fins.
/// La couleur du texte et des graduations éteintes suit le `foregroundStyle` de l'environnement.
/// `cardColor` détoure l'aiguille : le fond sur lequel la jauge est posée.
/// `animatesReveal` à `false` pose le repère d'emblée sur le score : WidgetKit rend une image fixe, sans `onAppear` ni animation.
public struct RecoveryGauge: View {
    public enum Style: Sendable {
        case large
        case compact

        var lineWidth: CGFloat {
            switch self {
            case .large: 3
            case .compact: 2.2
            }
        }

        /// Le nombre de graduations sur l'arc : une tous les 2,5 points en grand, tous les 5 points en compact.
        var tickCount: Int {
            switch self {
            case .large: 41
            case .compact: 21
            }
        }

        /// La longueur d'une graduation, en part du côté du cadran.
        var tickLength: CGFloat {
            switch self {
            case .large: 0.075
            case .compact: 0.085
            }
        }

        var idealWidth: CGFloat {
            switch self {
            case .large: 240
            case .compact: 116
            }
        }

        /// La taille du score en part du côté du cadran : les chiffres fins sont larges, ils restent un peu plus bas.
        var scoreScale: CGFloat {
            switch self {
            case .large: 0.32
            case .compact: 0.32
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
    @Environment(\.colorScheme) private var colorScheme
    /// « sur 100 » grandit avec Dynamic Type, jusqu'à 1,5 fois : le score, lui, reste dimensionné par le cadran (grands chiffres).
    @ScaledMetric(relativeTo: .caption2) private var captionScale: CGFloat = 1

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
        let length = side * style.tickLength
        let fraction = GaugeGeometry.fraction(for: shownScore)
        return ZStack {
            TickRing(from: 0, to: 1, count: style.tickCount, length: length, inset: style.lineWidth / 2)
                .stroke(.foreground, style: strokeStyle)
                .opacity(0.16)
            if score != nil {
                TickRing(from: 0, to: fraction, count: style.tickCount, length: length, inset: style.lineWidth / 2)
                    .stroke(trail(to: fraction), style: strokeStyle)
                    // Une lueur sur le noir ; sur le papier, l'encre n'en a pas besoin.
                    .shadow(color: toneColor.opacity(colorScheme == .dark ? 0.55 : 0), radius: side * 0.025)
                Needle(fraction: fraction, length: length * 2.1, inset: style.lineWidth / 2)
                    .stroke(cardColor.opacity(0.7), style: StrokeStyle(lineWidth: style.lineWidth * 3.2, lineCap: .round))
                Needle(fraction: fraction, length: length * 2.1, inset: style.lineWidth / 2)
                    .stroke(.foreground, style: StrokeStyle(lineWidth: style.lineWidth * 1.6, lineCap: .round))
            }
        }
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
    }

    /// La teinte de la catégorie : blanc en forme, gris en fatigue, signal en surmenage.
    private var toneColor: Color {
        category?.tone.color(onOpal: false) ?? PulsePalette.ok
    }

    /// La traînée : les graduations s'éclairent du début de l'arc jusqu'au score, où elles prennent toute la teinte.
    private func trail(to fraction: Double) -> AngularGradient {
        let end = max(fraction, 0.001)
        return AngularGradient(
            stops: [
                .init(color: toneColor.opacity(0.18), location: 0),
                .init(color: toneColor.opacity(0.55), location: end * 0.6),
                .init(color: toneColor, location: end),
                .init(color: toneColor, location: 1)
            ],
            center: .center,
            startAngle: .degrees(GaugeGeometry.startDegrees),
            endAngle: .degrees(GaugeGeometry.startDegrees + GaugeGeometry.sweepDegrees)
        )
    }

    // MARK: Score

    private func scoreLabel(side: CGFloat) -> some View {
        VStack(spacing: side * 0.026) {
            Text(verbatim: Self.roundedScore(score).map(String.init) ?? "—")
                .font(PulseFont.score(size: side * style.scoreScale))
                // Un nouveau score fait rouler les chiffres au lieu de les remplacer d'un coup.
                .pulseNumericTransition(value: Double(Self.roundedScore(score) ?? 0))
                .pulseAnimation(.snappy, value: Self.roundedScore(score))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if style.showsCaption {
                Text(String(localized: "sur 100", bundle: .module))
                    .font(.system(size: max(10, side * 0.045) * min(captionScale, 1.5), weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .tracking(1.6)
                    .foregroundStyle(PulsePalette.opalMuted)
            }
        }
        .padding(.top, side * 0.15)
    }

    // MARK: Animation

    private func reveal() {
        let target = Self.initialScore(score: score, animatesReveal: false)
        if reduceMotion || !animatesReveal {
            shownScore = target
        } else {
            PulseMotion.perform(.spring(response: 1.1, dampingFraction: 0.82), reduceMotion: reduceMotion) { shownScore = target }
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

/// Les graduations de `from` à `to` (parts de l'arc, 0…1), tracées vers le centre depuis le bord du cadran.
/// Animable : la lunette s'allume graduation par graduation quand `to` change.
private struct TickRing: Shape {
    var from: Double
    var to: Double
    let count: Int
    let length: CGFloat
    let inset: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(from, to) }
        set { from = newValue.first; to = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 1 else { return path }
        let outer = max(0, min(rect.width, rect.height) / 2 - inset)
        let inner = max(0, outer - length)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<count {
            let fraction = Double(index) / Double(count - 1)
            guard fraction >= from - 1e-6, fraction <= to + 1e-6 else { continue }
            let radians = GaugeGeometry.angle(for: fraction * 100).radians
            let direction = CGPoint(x: cos(radians), y: sin(radians))
            path.move(to: CGPoint(x: center.x + outer * direction.x, y: center.y + outer * direction.y))
            path.addLine(to: CGPoint(x: center.x + inner * direction.x, y: center.y + inner * direction.y))
        }
        return path
    }
}

/// L'aiguille : une graduation plus longue, au score. Animable, elle suit l'arc.
private struct Needle: Shape {
    var fraction: Double
    let length: CGFloat
    let inset: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let outer = max(0, min(rect.width, rect.height) / 2 - inset)
        let inner = max(0, outer - length)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radians = GaugeGeometry.angle(for: fraction * 100).radians
        var path = Path()
        path.move(to: CGPoint(x: center.x + outer * cos(radians), y: center.y + outer * sin(radians)))
        path.addLine(to: CGPoint(x: center.x + inner * cos(radians), y: center.y + inner * sin(radians)))
        return path
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

#Preview("Large, sur la dalle tramée") {
    ScrollView {
        OpalCard(heat: 70) { GaugePreviewRow(style: .large, cardColor: PulsePalette.opal).frame(maxWidth: .infinity) }
            .padding()
    }
    .background(PulsePalette.background)
}

#Preview("Accessibilité 3") {
    OpalCard(heat: 70) {
        RecoveryGauge(score: 58, category: .moderateFatigue, style: .large, cardColor: PulsePalette.opal)
            .frame(maxWidth: .infinity)
    }
    .padding()
    .background(PulsePalette.background)
    .dynamicTypeSize(.accessibility3)
}

#Preview("Compact, sur fond sombre") {
    GaugePreviewRow(style: .compact, cardColor: PulsePalette.surface)
        .foregroundStyle(PulsePalette.text)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PulsePalette.surface)
}
