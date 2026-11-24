import PulseDesignSystem
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Toucher

/// Les boutons de la séance s'enfoncent sous le doigt. Pas de tic haptique ici : le geste qui suit (touche, validation) a le sien.
struct LivePressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .pulseAnimation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Respiration

private struct BreathingModifier: ViewModifier {
    let isOn: Bool
    let glow: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isOn && !reduceMotion {
            content.phaseAnimator([false, true]) { view, phase in
                view
                    .scaleEffect(phase ? 1.05 : 1)
                    .shadow(color: glow.opacity(phase ? 0.5 : 0.12), radius: phase ? 14 : 4)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Une respiration lente (échelle et lueur) tant que `isOn` est vrai ; rien avec « Réduire les animations ».
    func breathing(_ isOn: Bool, glow: Color) -> some View {
        modifier(BreathingModifier(isOn: isOn, glow: glow))
    }
}

// MARK: - Éclat de validation

private struct BurstValues {
    var scale: CGFloat = 1
    var opacity: Double = 0
}

private struct ValidationBurstModifier<S: Shape>: ViewModifier {
    let trigger: Int
    let shape: S
    let color: Color
    let style: Style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Style {
        /// Un anneau qui s'élargit et s'efface, autour de la coche.
        case ring
        /// Un voile qui s'allume puis s'éteint, sur toute la ligne.
        case flash
    }

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                shapeLayer
                    .keyframeAnimator(initialValue: BurstValues(), trigger: trigger) { view, value in
                        view.scaleEffect(value.scale).opacity(value.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(style == .ring ? 0.8 : 1, duration: 0.02)
                            CubicKeyframe(0, duration: style == .ring ? 0.5 : 0.7)
                        }
                        KeyframeTrack(\.scale) {
                            LinearKeyframe(1, duration: 0.02)
                            CubicKeyframe(style == .ring ? 1.75 : 1, duration: 0.5)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var shapeLayer: some View {
        switch style {
        case .ring: shape.stroke(color, lineWidth: 2)
        case .flash: shape.fill(color)
        }
    }
}

extension View {
    /// Un anneau qui jaillit de la vue chaque fois que `trigger` change (une série validée).
    func validationRing(trigger: Int, color: Color) -> some View {
        modifier(ValidationBurstModifier(trigger: trigger, shape: Circle(), color: color, style: .ring))
    }

    /// Un voile bref sur la vue chaque fois que `trigger` change.
    func validationFlash(trigger: Int, color: Color, in shape: some Shape) -> some View {
        modifier(ValidationBurstModifier(trigger: trigger, shape: shape, color: color, style: .flash))
    }
}

// MARK: - Progression de la séance

/// Une barre de segments sous les statistiques, un par série de travail : les faits à l'encre, les autres en filet. Au-delà
/// de 40 séries, les segments deviendraient des poils : la barre est alors continue. Muette, les statistiques disent déjà
/// « 4 séries faites sur 14 ».
struct SessionProgressBar: View {
    static let maxSegments = 40

    let done: Int
    let planned: Int

    var body: some View {
        Group {
            if planned <= Self.maxSegments {
                HStack(spacing: 3) {
                    ForEach(0..<max(planned, 1), id: \.self) { index in
                        Capsule()
                            .fill(index < done ? PulsePalette.text : PulsePalette.line)
                            // Le dernier segment fait s'allume un instant plus haut que les autres.
                            .scaleEffect(y: index == done - 1 ? 1.6 : 1)
                    }
                }
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PulsePalette.line)
                        Capsule()
                            .fill(PulsePalette.text)
                            .frame(width: proxy.size.width * Self.fraction(done: done, planned: planned))
                    }
                }
            }
        }
        .frame(height: 4)
        .pulseAnimation(.spring(response: 0.45, dampingFraction: 0.7), value: done)
        .pulseAnimation(.spring(response: 0.45, dampingFraction: 0.8), value: planned)
        .accessibilityHidden(true)
    }

    nonisolated static func fraction(done: Int, planned: Int) -> CGFloat {
        guard planned > 0 else { return 0 }
        return min(1, max(0, CGFloat(done) / CGFloat(planned)))
    }
}

// MARK: - Progression d'un exercice

/// L'anneau d'une carte : les séries validées de l'exercice sur toutes ses séries, le compte au centre. Plein, coché et
/// rebondissant quand tout est fait.
struct ExerciseProgressRing: View {
    let done: Int
    let total: Int
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 34

    private var isComplete: Bool { total > 0 && done >= total }

    var body: some View {
        ZStack {
            Circle().stroke(PulsePalette.line, lineWidth: 3)
            Circle()
                .trim(from: 0, to: SessionProgressBar.fraction(done: done, planned: total))
                .stroke(PulsePalette.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(PulsePalette.text)
                .scaleEffect(isComplete ? 1 : 0.2)
                .opacity(isComplete ? 1 : 0)
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .black))
                    .foregroundStyle(PulsePalette.liveBackground)
                    .pulseTransition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                Text("\(done)")
                    .font(.system(size: size * 0.38, weight: .bold).monospacedDigit())
                    .foregroundStyle(done > 0 ? PulsePalette.text : PulsePalette.muted)
                    .pulseNumericTransition(value: Double(done))
            }
        }
        .frame(width: min(size, 52), height: min(size, 52))
        .pulseAnimation(.spring(response: 0.4, dampingFraction: 0.55), value: done)
        .pulseAnimation(.spring(response: 0.4, dampingFraction: 0.55), value: isComplete)
    }
}

// MARK: - Icône de balayage

/// L'icône d'une action de balayage, dans sa propre couleur. iOS peint en blanc les icônes des actions de balayage et ignore
/// `foregroundStyle` : l'image est rendue d'avance en couleur d'origine (`alwaysOriginal`), résolue en sombre comme l'écran de
/// séance. VoiceOver lit `title`.
struct LiveSwipeIcon: View {
    let systemName: String
    let title: String
    let color: Color

    init(_ systemName: String, title: String, color: Color) {
        self.systemName = systemName
        self.title = title
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            icon
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var icon: some View {
        #if os(iOS)
        if let image = Self.coloredSymbol(systemName, color: color) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemName)
        }
        #else
        Image(systemName: systemName).foregroundStyle(color)
        #endif
    }

    #if os(iOS)
    private static func coloredSymbol(_ name: String, color: Color) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        return UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(resolved, renderingMode: .alwaysOriginal)
    }
    #endif
}
