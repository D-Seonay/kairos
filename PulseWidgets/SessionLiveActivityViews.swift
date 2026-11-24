import AppIntents
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetFeature

/// Les couleurs de la Live Activity. L'extension ne lit pas le thème du profil : elle prend l'accent par défaut (Ivoire).
/// La séance est toujours sombre (fond noir) : l'accent et son encre sont fixés à leurs tirages sombres. Avec le tirage dynamique,
/// l'apparence claire du système rendrait l'accent en encre noire sur le noir de l'activité (1,1:1).
enum SessionActivityStyle {
    static let accent = Color(PulsePalette.accent(for: .amber).accent.dark)
    static let accentInk = Color(PulsePalette.accent(for: .amber).accentInk.dark)
}

extension View {
    /// La Live Activity pose un fond noir quelle que soit l'apparence du système : ses vues se composent toujours en sombre.
    func sessionActivityDark() -> some View {
        environment(\.colorScheme, .dark)
    }
}

/// L'état affiché de l'activité. Une activité périmée (`staleDate` = fin du repos) compte comme hors repos : l'écran verrouillé et
/// la Dynamic Island n'attendent pas une mise à jour de l'app pour cacher le repos fini et ses boutons.
struct SessionActivityModel {
    let content: PulseSessionAttributes.ContentState
    let isStale: Bool

    var title: String { content.title }
    var startedAt: Date { content.startedAt }
    var nextSet: String? { content.nextSet }
    var plannedSets: Int { max(content.plannedSets ?? 0, 0) }
    var doneSets: Int { min(max(content.doneSets ?? 0, 0), plannedSets) }

    /// Une séance sans série prévue (séance libre vide) n'affiche pas de progression.
    var showsProgress: Bool { plannedSets > 0 }

    /// L'intervalle du repos en cours ; `nil` hors repos. Les comptes à rebours partent des dates, jamais d'un compteur.
    var restInterval: ClosedRange<Date>? {
        guard !isStale, let restEndsAt = content.restEndsAt else { return nil }
        return min(content.restStartedAt ?? restEndsAt, restEndsAt)...restEndsAt
    }

    /// Ce que VoiceOver lit pour le titre, la progression et la série suivante ; le minuteur système lit lui-même le temps.
    var spokenLabel: String {
        SessionActivityText.accessibilityLabel(title: title, isResting: restInterval != nil, nextSet: nextSet,
                                               doneSets: doneSets, plannedSets: plannedSets)
    }
}

/// L'anneau du repos : un minuteur système qui se vide jusqu'à `restEndsAt`.
struct SessionRestRing: View {
    let interval: ClosedRange<Date>

    var body: some View {
        ProgressView(timerInterval: interval, countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(SessionActivityStyle.accent)
        .accessibilityHidden(true)
    }
}

/// L'anneau des séries de travail validées, comme la barre en haut de l'écran de séance. Un haltère au centre quand il y a la place.
struct SessionSetsRing: View {
    let state: SessionActivityModel
    var showsIcon = true

    var body: some View {
        ProgressView(value: Double(state.doneSets), total: Double(max(state.plannedSets, 1))) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(SessionActivityStyle.accent)
        .overlay {
            if showsIcon {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
                    .imageScale(.small)
                    .foregroundStyle(SessionActivityStyle.accent)
            }
        }
        .accessibilityHidden(true)
    }
}

/// La barre des séries de travail validées, sous l'en-tête de l'écran verrouillé.
struct SessionProgressBar: View {
    let state: SessionActivityModel

    var body: some View {
        ProgressView(value: Double(state.doneSets), total: Double(max(state.plannedSets, 1)))
            .progressViewStyle(.linear)
            .tint(SessionActivityStyle.accent)
            .accessibilityHidden(true)
    }
}

/// À gauche de l'en-tête : l'anneau du repos pendant un repos, sinon l'anneau des séries, ou l'haltère sans série prévue.
struct SessionLeadingGlyph: View {
    let state: SessionActivityModel
    let iconFont: Font

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
        } else if state.showsProgress {
            SessionSetsRing(state: state)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(iconFont)
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityHidden(true)
        }
    }
}

/// Le temps restant du repos, ou la durée écoulée depuis le début de la séance, en minuteur système.
struct SessionClockText: View {
    let state: SessionActivityModel

    var body: some View {
        Group {
            if let interval = state.restInterval {
                Text(timerInterval: interval, pauseTime: nil, countsDown: true, showsHours: false)
            } else {
                Text(timerInterval: state.startedAt...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: true)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }
}

/// Un bouton du repos : −30 s, +30 s ou Passer.
struct SessionRestButton<Intent: AppIntent>: View {
    let intent: Intent
    let title: String
    let label: String
    var isPrimary = false

    var body: some View {
        Button(intent: intent) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isPrimary ? SessionActivityStyle.accentInk : .white)
                .background(isPrimary ? SessionActivityStyle.accent : .white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Les trois boutons du repos.
struct SessionRestButtons: View {
    var body: some View {
        HStack(spacing: 8) {
            SessionRestButton(intent: RestMinus30Intent(), title: SessionActivityText.minus30Title,
                              label: SessionActivityText.minus30Label)
            SessionRestButton(intent: RestPlus30Intent(), title: SessionActivityText.plus30Title,
                              label: SessionActivityText.plus30Label)
            SessionRestButton(intent: SkipRestIntent(), title: SessionActivityText.skipTitle,
                              label: SessionActivityText.skipLabel, isPrimary: true)
        }
    }
}

/// La série suivante, sur deux lignes au plus.
struct SessionNextSetText: View {
    let nextSet: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SessionActivityText.nextSetTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text(nextSet)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Le titre (« Repos » pendant un repos, celui de la séance sinon) suivi de « 4 / 15 », et la série suivante, lus d'un seul
/// tenant par VoiceOver.
struct SessionTitleAndNextSet: View {
    let state: SessionActivityModel
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(state.restInterval == nil ? state.title : SessionActivityText.restTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if state.showsProgress {
                    Text(SessionActivityText.progressText(done: state.doneSets, planned: state.plannedSets))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .layoutPriority(1)
                        .contentTransition(.numericText(value: Double(state.doneSets)))
                }
            }
            if let nextSet = state.nextSet {
                SessionNextSetText(nextSet: nextSet)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.spokenLabel)
    }
}

/// L'écran verrouillé : anneau, temps restant, série suivante et boutons pendant un repos ; anneau des séries, titre, durée
/// écoulée et série suivante sinon. La barre des séries passe sous l'en-tête.
struct SessionLockScreenView: View {
    let state: SessionActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if state.showsProgress {
                SessionProgressBar(state: state)
            }
            if state.restInterval != nil {
                SessionRestButtons()
            }
        }
        .padding(16)
        // L'écran verrouillé de la Live Activity plafonne à 160 pt de haut : au-delà, les boutons du repos seraient rognés.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sessionActivityDark()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            SessionLeadingGlyph(state: state, iconFont: .title2)
                .frame(width: 44, height: 44)
            SessionTitleAndNextSet(state: state, spacing: 4)
            Spacer(minLength: 8)
            SessionClockText(state: state)
                .font(PulseFont.value(.largeTitle))
                .foregroundStyle(SessionActivityStyle.accent)
        }
    }
}

/// À gauche de la Dynamic Island étendue : l'anneau du repos, l'anneau des séries hors repos, ou l'haltère sans série prévue.
struct SessionIslandLeading: View {
    let state: SessionActivityModel

    var body: some View {
        SessionLeadingGlyph(state: state, iconFont: .title3)
            .frame(width: 40, height: 40)
            .sessionActivityDark()
    }
}

/// À gauche de la Dynamic Island compacte : l'anneau des séries et « 4/15 », ou l'haltère sans série prévue.
struct SessionCompactLeading: View {
    let state: SessionActivityModel

    var body: some View {
        Group {
            if state.showsProgress {
                HStack(spacing: 4) {
                    SessionSetsRing(state: state, showsIcon: false)
                        .frame(width: 16, height: 16)
                    Text("\(state.doneSets)/\(state.plannedSets)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(SessionActivityStyle.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(value: Double(state.doneSets)))
                }
                .frame(maxWidth: 56, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(SessionActivityText.progressSpoken(done: state.doneSets, planned: state.plannedSets))
            } else {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(SessionActivityStyle.accent)
                    .accessibilityHidden(true)
            }
        }
        .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island étendue : le temps restant, ou la durée écoulée.
struct SessionIslandTrailing: View {
    let state: SessionActivityModel

    var body: some View {
        SessionClockText(state: state)
            .font(PulseFont.value(.title))
            .foregroundStyle(SessionActivityStyle.accent)
            .sessionActivityDark()
    }
}

/// Sous la Dynamic Island étendue : le titre du repos ou de la séance, la série suivante et les boutons.
struct SessionIslandBottom: View {
    let state: SessionActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SessionTitleAndNextSet(state: state, spacing: 2)
            if state.restInterval != nil {
                SessionRestButtons()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island compacte : le temps restant du repos, ou la durée écoulée.
struct SessionCompactTime: View {
    let state: SessionActivityModel

    var body: some View {
        SessionClockText(state: state)
            .font(.caption.weight(.bold))
            .foregroundStyle(SessionActivityStyle.accent)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 52, alignment: .trailing)
            .sessionActivityDark()
    }
}

/// La Dynamic Island minimale : l'anneau du repos, l'anneau des séries hors repos, ou l'icône sans série prévue.
struct SessionMinimalView: View {
    let state: SessionActivityModel

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
                .padding(2)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        } else if state.showsProgress {
            SessionSetsRing(state: state)
                .padding(2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        } else {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityLabel(state.spokenLabel)
                .sessionActivityDark()
        }
    }
}
