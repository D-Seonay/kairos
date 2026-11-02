import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le bandeau de repos (spec M4 §15.1) : un anneau et le temps restant, la série suivante, −30 s, +30 s et Passer. Il disparaît
/// à la fin du repos, qui fait vibrer une fois. Le temps est affiché par `Text(timerInterval:)`, l'anneau par une `TimelineView`.
struct RestBanner: View {
    let model: LiveSessionModel
    let rest: LiveRest
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: rest.startedAt, by: 1)) { context in
            let isOver = context.date >= rest.endsAt
            Group {
                if !isOver { banner(fraction: Self.remainingFraction(of: rest, at: context.date)) }
            }
            .onChange(of: isOver) { _, over in
                if over { model.didReachRestEnd() }
            }
        }
    }

    private func banner(fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let next = Self.nextSetText(in: model.session) {
                Text(next)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .lineLimit(1)
                    .accessibilityLabel(String(localized: "Série suivante : \(next)", bundle: .module))
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) {
                    ring(fraction: fraction)
                    buttons
                }
            } else {
                HStack(spacing: 6) {
                    ring(fraction: fraction)
                    buttons
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulsePalette.surface2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LiveSessionIdentifiers.restBar)
    }

    private func ring(fraction: Double) -> some View {
        let accent = Color(PulsePalette.accent(for: theme).accent)
        return ZStack {
            Circle().stroke(PulsePalette.line, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
            Text(timerInterval: rest.startedAt...rest.endsAt, pauseTime: nil, countsDown: true, showsHours: false)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(PulsePalette.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(6)
        }
        .frame(width: LiveSetRow.targetHeight, height: LiveSetRow.targetHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Repos restant", bundle: .module))
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            button(String(localized: "\u{2212}30 s", bundle: .module), spoken: String(localized: "Retirer 30 secondes", bundle: .module),
                   identifier: LiveSessionIdentifiers.restMinus30) { await model.restMinus30() }
            button(String(localized: "+30 s", bundle: .module), spoken: String(localized: "Ajouter 30 secondes", bundle: .module),
                   identifier: LiveSessionIdentifiers.restPlus30) { await model.restPlus30() }
            button(String(localized: "Passer", bundle: .module), spoken: String(localized: "Passer le repos", bundle: .module),
                   identifier: LiveSessionIdentifiers.restSkip, isProminent: true) { await model.skipRest() }
        }
    }

    private func button(_ title: String, spoken: String, identifier: String, isProminent: Bool = false,
                        action: @escaping () async -> Void) -> some View {
        let palette = PulsePalette.accent(for: theme)
        return Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isProminent ? Color(palette.accentInk) : PulsePalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: LiveSetRow.targetHeight)
                .background(isProminent ? Color(palette.accent) : PulsePalette.surface,
                            in: RoundedRectangle(cornerRadius: PulseMetrics.radiusTiny, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Textes

extension RestBanner {
    /// « Développé couché, série 3 : 70 kg × 5 » : la prochaine série non validée ; `nil` quand tout est validé.
    nonisolated static func nextSetText(in session: LiveSession) -> String? {
        guard let next = session.nextSet else { return nil }
        let exercise = session.exercises[next.exerciseIndex]
        let set = exercise.sets[next.setIndex]
        let title = String(localized: "\(exercise.name), série \(next.setIndex + 1)", bundle: .module)
        guard let planned = LiveSetRow.plannedText(set, loadKind: exercise.loadKind, tracksDuration: exercise.tracksDuration) else {
            return title
        }
        return String(localized: "\(title) : \(planned)", bundle: .module)
    }

    /// La part du repos qui reste, de 1 à 0. +30 s allonge la durée de référence, la fin seule bougeant.
    nonisolated static func remainingFraction(of rest: LiveRest, at now: Date) -> Double {
        let total = rest.endsAt.timeIntervalSince(rest.startedAt)
        guard total > 0 else { return 0 }
        return min(1, max(0, rest.endsAt.timeIntervalSince(now) / total))
    }
}
