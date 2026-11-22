import PulseDesignSystem
import PulseDomain
import PulseServices
import SwiftUI

/// Le bandeau de repos (spec M4 §15.1) : un anneau et le temps restant, la série suivante, −30 s, +30 s et Passer. Il disparaît
/// à la fin du repos, qui fait vibrer une fois. Le temps est affiché par `Text(timerInterval:)`, l'anneau par une `TimelineView`.
/// Le début et la fin du repos sont annoncés par l'écran (`announcement(for:endReached:in:)`), le bandeau étant lu après la
/// liste.
struct RestBanner: View {
    let model: LiveSessionModel
    let rest: LiveRest
    @ScaledMetric(relativeTo: .headline) private var ringSize = LiveSetRow.targetHeight
    @Environment(\.pulseTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.periodic(from: rest.startedAt, by: 1)) { context in
            let isOver = context.date >= rest.endsAt
            ZStack {
                if !isOver { banner(at: context.date) }
                // Hors du `if` : la vue qui voit passer la fin du repos ne disparaît pas avec le bandeau.
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .onChange(of: isOver) { _, over in
                        if over { model.didReachRestEnd() }
                    }
            }
        }
    }

    private func banner(at now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let next = Self.nextSetText(in: model.session) {
                Text(next)
                    .font(.footnote)
                    .foregroundStyle(PulsePalette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Self.nextSetSpokenLabel(in: model.session) ?? next)
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) {
                    ring(at: now)
                    buttons
                }
            } else {
                HStack(spacing: 6) {
                    ring(at: now)
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

    private func ring(at now: Date) -> some View {
        let palette = PulsePalette.accent(for: theme)
        let fraction = Self.remainingFraction(of: rest, at: now)
        return ZStack {
            Circle().stroke(PulsePalette.line, lineWidth: 4).accessibilityHidden(true)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(AngularGradient(colors: [Color(palette.accent), Color(palette.accent2)], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .shadow(color: Color(palette.accent2).opacity(0.6), radius: 4)
                .rotationEffect(.degrees(-90))
                .pulseAnimation(.linear(duration: 1), value: fraction)
                .accessibilityHidden(true)
            Text(timerInterval: rest.startedAt...rest.endsAt, pauseTime: nil, countsDown: true, showsHours: false)
                .font(PulseFont.value(.headline))
                .foregroundStyle(PulsePalette.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(6)
        }
        .frame(width: ringSize, height: ringSize)
        // Le temps restant dit en mots, une fois par seconde : « 1 minute 30 ».
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Repos restant", bundle: .module))
        .accessibilityValue(Self.remainingSpokenText(of: rest, at: now))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Les trois boutons, en colonne aux tailles d'accessibilité pour que chacun garde la largeur de son texte.
    private var buttons: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            button(String(localized: "\u{2212}30 s", bundle: .module), spoken: String(localized: "Retirer 30 secondes", bundle: .module),
                   identifier: LiveSessionIdentifiers.restMinus30) {
                await model.restMinus30()
                // −30 s peut finir le repos : le bandeau disparaît, on dit que c'est fini.
                if model.session.rest == nil {
                    PulseAnnouncement.post(Self.restEndedText(next: Self.nextSetSpokenText(in: model.session)))
                }
            }
            button(String(localized: "+30 s", bundle: .module), spoken: String(localized: "Ajouter 30 secondes", bundle: .module),
                   identifier: LiveSessionIdentifiers.restPlus30) { await model.restPlus30() }
            button(String(localized: "Passer", bundle: .module), spoken: String(localized: "Passer le repos", bundle: .module),
                   identifier: LiveSessionIdentifiers.restSkip, isProminent: true) { await Self.skipRest(on: model) }
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
                .background(isProminent ? AnyShapeStyle(Color(palette.accent)) : AnyShapeStyle(PulsePalette.surface), in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Passer

extension RestBanner {
    /// Passe le repos et le dit : le bandeau, qui avait le focus, disparaît.
    static func skipRest(on model: LiveSessionModel) async {
        await model.skipRest()
        guard model.session.rest == nil else { return }
        PulseAnnouncement.post(restSkippedText(next: nextSetSpokenText(in: model.session)))
    }
}

// MARK: - Textes

/// Une annonce de repos et ce qui l'identifie : un même repos ne s'annonce qu'une fois quand il commence (même après +30 s ou
/// −30 s, qui ne touchent qu'à la fin) et une fois quand il finit.
struct RestAnnouncement: Equatable {
    enum Event: Hashable {
        case started(Date)
        case ended(Date)
    }

    let event: Event
    let text: String
}

extension RestBanner {
    typealias Announcement = RestAnnouncement

    /// L'annonce du repos en cours : « Repos de 1 minute 30 » tant qu'il court, « Repos terminé. Série suivante : … » une fois
    /// sa fin atteinte (`endReached`, le début du repos dont la fin a sonné) ; `nil` sans repos.
    nonisolated static func announcement(for rest: LiveRest?, endReached: Date?, in session: LiveSession) -> Announcement? {
        guard let rest else { return nil }
        if endReached == rest.startedAt {
            return Announcement(event: .ended(rest.startedAt), text: restEndedText(next: nextSetSpokenText(in: session)))
        }
        let seconds = Int(rest.endsAt.timeIntervalSince(rest.startedAt).rounded())
        return Announcement(event: .started(rest.startedAt), text: restStartedText(seconds: seconds))
    }

    /// « Repos de 1 minute 30 ».
    nonisolated static func restStartedText(seconds: Int) -> String {
        String(localized: "Repos de \(PulseSpoken.duration(seconds: seconds))", bundle: .module)
    }

    /// « Repos terminé. Série suivante : Développé couché, série 3 : 70 kilos, 5 répétitions » ; « Repos terminé » quand tout
    /// est validé.
    nonisolated static func restEndedText(next: String?) -> String {
        guard let next else { return String(localized: "Repos terminé", bundle: .module) }
        return String(localized: "Repos terminé. Série suivante : \(next)", bundle: .module)
    }

    /// « Repos passé. Série suivante : … » ; « Repos passé » quand tout est validé.
    nonisolated static func restSkippedText(next: String?) -> String {
        guard let next else { return String(localized: "Repos passé", bundle: .module) }
        return String(localized: "Repos passé. Série suivante : \(next)", bundle: .module)
    }

    /// « 1 minute 30 » : le temps restant, arrondi à la seconde du dessus comme le chrono affiché.
    nonisolated static func remainingSpokenText(of rest: LiveRest, at now: Date) -> String {
        let seconds = Int(max(0, rest.endsAt.timeIntervalSince(now)).rounded(.up))
        return PulseSpoken.duration(seconds: seconds)
    }

    /// « Développé couché, série 3 : 70 kilos, 5 répétitions » : la série suivante dite en mots ; `nil` quand tout est validé.
    nonisolated static func nextSetSpokenText(in session: LiveSession) -> String? {
        guard let next = session.nextSet(after: session.lastCheckedSet) else { return nil }
        let exercise = session.exercises[next.exerciseIndex]
        let set = exercise.sets[next.setIndex]
        let title = String(localized: "\(exercise.name), série \(next.setIndex + 1)", bundle: .module)
        guard let planned = LiveSetRow.plannedSpokenText(for: set, loadKind: exercise.loadKind,
                                                         tracksDuration: exercise.tracksDuration) else { return title }
        return String(localized: "\(title) : \(planned)", bundle: .module)
    }

    /// « Série suivante : Développé couché, série 3 : 70 kilos, 5 répétitions ».
    nonisolated static func nextSetSpokenLabel(in session: LiveSession) -> String? {
        nextSetSpokenText(in: session).map { String(localized: "Série suivante : \($0)", bundle: .module) }
    }

    /// « Développé couché, série 3 : 70 kg × 5 » : la série non validée qui suit la dernière validée ; `nil` quand tout est
    /// validé.
    nonisolated static func nextSetText(in session: LiveSession) -> String? {
        guard let next = session.nextSet(after: session.lastCheckedSet) else { return nil }
        let exercise = session.exercises[next.exerciseIndex]
        let set = exercise.sets[next.setIndex]
        let title = String(localized: "\(exercise.name), série \(next.setIndex + 1)", bundle: .module)
        guard let planned = exercise.plannedText(for: set) else {
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
