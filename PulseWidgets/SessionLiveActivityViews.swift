import AppIntents
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetFeature

/// Les couleurs de la Live Activity. L'extension ne lit pas le thème du profil : elle prend l'accent par défaut (ambre).
enum SessionActivityStyle {
    static let accent = Color(PulsePalette.accent(for: .amber).accent)
    static let accentInk = Color(PulsePalette.accent(for: .amber).accentInk)
}

/// L'état affiché de l'activité. Une activité périmée (`staleDate` = fin du repos) compte comme hors repos : l'écran verrouillé et
/// la Dynamic Island n'attendent pas une mise à jour de l'app pour cacher le repos fini et ses boutons.
struct SessionActivityModel {
    let content: PulseSessionAttributes.ContentState
    let isStale: Bool

    var title: String { content.title }
    var startedAt: Date { content.startedAt }
    var nextSet: String? { content.nextSet }

    /// L'intervalle du repos en cours ; `nil` hors repos. Les comptes à rebours partent des dates, jamais d'un compteur.
    var restInterval: ClosedRange<Date>? {
        guard !isStale, let restEndsAt = content.restEndsAt else { return nil }
        return min(content.restStartedAt ?? restEndsAt, restEndsAt)...restEndsAt
    }

    /// Ce que VoiceOver lit pour le titre et la série suivante ; le minuteur système lit lui-même le temps.
    var spokenLabel: String {
        SessionActivityText.accessibilityLabel(title: title, isResting: restInterval != nil, nextSet: nextSet)
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

/// Le titre (« Repos » pendant un repos, celui de la séance sinon) et la série suivante, lus d'un seul tenant par VoiceOver.
struct SessionTitleAndNextSet: View {
    let state: SessionActivityModel
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(state.restInterval == nil ? state.title : SessionActivityText.restTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            if let nextSet = state.nextSet {
                SessionNextSetText(nextSet: nextSet)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.spokenLabel)
    }
}

/// L'écran verrouillé : anneau, temps restant, série suivante et boutons pendant un repos ; titre, durée écoulée et série suivante
/// sinon.
struct SessionLockScreenView: View {
    let state: SessionActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if state.restInterval != nil {
                SessionRestButtons()
            }
        }
        .padding(16)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let interval = state.restInterval {
                SessionRestRing(interval: interval)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(SessionActivityStyle.accent)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            SessionTitleAndNextSet(state: state, spacing: 4)
            Spacer(minLength: 8)
            SessionClockText(state: state)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(SessionActivityStyle.accent)
        }
    }
}

/// À gauche de la Dynamic Island étendue : l'anneau du repos, ou l'icône hors repos.
struct SessionIslandLeading: View {
    let state: SessionActivityModel

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
                .frame(width: 40, height: 40)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityHidden(true)
        }
    }
}

/// À droite de la Dynamic Island étendue : le temps restant, ou la durée écoulée.
struct SessionIslandTrailing: View {
    let state: SessionActivityModel

    var body: some View {
        SessionClockText(state: state)
            .font(.system(.title2, design: .rounded, weight: .heavy))
            .foregroundStyle(SessionActivityStyle.accent)
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
    }
}

/// La Dynamic Island minimale : l'anneau du repos, ou l'icône hors repos.
struct SessionMinimalView: View {
    let state: SessionActivityModel

    var body: some View {
        if let interval = state.restInterval {
            SessionRestRing(interval: interval)
                .padding(2)
                .accessibilityLabel(state.spokenLabel)
        } else {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(SessionActivityStyle.accent)
                .accessibilityLabel(state.spokenLabel)
        }
    }
}
