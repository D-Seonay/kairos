import AppIntents
import PulseDesignSystem
import PulseDomain
import PulseLiveActivity
import SwiftUI
import WidgetFeature

/// Les couleurs de la Live Activity de course : une seule couleur signal, celle de la course. L'activité est toujours sombre (fond
/// noir) : la couleur de la course est fixée à son tirage sombre, comme `SessionActivityStyle`.
enum RunActivityStyle {
    static let accent = Color(PulsePalette.runRGBA)
    static let accentInk = Color(PulsePalette.liveBackgroundRGBA)
}

/// L'état affiché de l'activité de course : l'identifiant vient des attributs, le reste de `ContentState`.
struct RunActivityModel {
    let sessionID: UUID
    let content: PulseRunAttributes.ContentState

    var title: String { content.title }
    var isPaused: Bool { content.isPaused }

    /// Le minuteur système part de cette date ; `nil` en pause (ou sans date, par prudence : on affiche alors le temps figé).
    var timerStart: Date? { isPaused ? nil : content.timerStart }

    var state: RunActivityState {
        RunActivityState(sessionID: sessionID, title: title, timerStart: content.timerStart,
                         frozenElapsedSeconds: content.frozenElapsedSeconds, distanceMeters: content.distanceMeters,
                         averagePaceSecondsPerKm: content.averagePaceSecondsPerKm, isPaused: isPaused)
    }

    var distanceText: String { RunActivityText.distance(content.distanceMeters) }
    var paceText: String { RunActivityText.pace(content.averagePaceSecondsPerKm) }

    /// Ce que VoiceOver lit pour le titre, la distance et l'allure ; le minuteur système lit lui-même le temps en marche.
    var spokenLabel: String { RunActivityText.accessibilityLabel(state) }
}

/// Le temps de la course : minuteur système en mouvement, temps figé en pause.
struct RunClockText: View {
    let state: RunActivityModel

    var body: some View {
        Group {
            if let timerStart = state.timerStart {
                Text(timerInterval: timerStart...Date.distantFuture, pauseTime: nil, countsDown: false, showsHours: true)
            } else {
                Text(RunActivityText.elapsed(seconds: state.content.frozenElapsedSeconds))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }
}

/// Le bouton Pause ou Reprendre. Reprendre est le bouton plein : c'est l'action à faire quand la course est arrêtée.
struct RunToggleButton: View {
    let isPaused: Bool

    var body: some View {
        if isPaused {
            button(intent: RunResumeIntent(), title: RunActivityText.resumeTitle, label: RunActivityText.resumeLabel, isPrimary: true)
        } else {
            button(intent: RunPauseIntent(), title: RunActivityText.pauseTitle, label: RunActivityText.pauseLabel, isPrimary: false)
        }
    }

    private func button<Intent: AppIntent>(intent: Intent, title: String, label: String, isPrimary: Bool) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(isPrimary ? RunActivityStyle.accentInk : .white)
                .background(isPrimary ? RunActivityStyle.accent : .white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// « En pause », sous le temps figé.
struct RunPausedBadge: View {
    var body: some View {
        Text(RunActivityText.pausedTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RunActivityStyle.accent)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

/// Le titre, la distance et l'allure, lus d'un seul tenant par VoiceOver.
struct RunTitleAndMetrics: View {
    let state: RunActivityModel
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(state.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(verbatim: "\(state.distanceText) · \(state.paceText)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.spokenLabel)
    }
}

/// Le temps et, en pause, « En pause » dessous : un seul élément pour VoiceOver en pause (le temps figé est déjà dans le libellé
/// des métriques), le minuteur système en marche.
struct RunClockBlock: View {
    let state: RunActivityModel
    let font: Font

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            RunClockText(state: state)
                .font(font)
                .foregroundStyle(RunActivityStyle.accent)
                .accessibilityHidden(state.isPaused)
            if state.isPaused {
                RunPausedBadge()
            }
        }
    }
}

/// L'écran verrouillé : icône, titre, distance et allure, temps, et le bouton Pause ou Reprendre.
struct RunLockScreenView: View {
    let state: RunActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(RunActivityStyle.accent)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                RunTitleAndMetrics(state: state, spacing: 4)
                Spacer(minLength: 8)
                RunClockBlock(state: state, font: PulseFont.value(.largeTitle))
            }
            RunToggleButton(isPaused: state.isPaused)
        }
        .padding(16)
        // L'écran verrouillé de la Live Activity plafonne à 160 pt de haut : au-delà, le bouton serait rogné.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sessionActivityDark()
    }
}

/// À gauche de la Dynamic Island étendue : l'icône de la course.
struct RunIslandLeading: View {
    var body: some View {
        Image(systemName: "figure.run")
            .font(.title3)
            .foregroundStyle(RunActivityStyle.accent)
            .accessibilityHidden(true)
            .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island étendue : le temps, et « En pause » en pause.
struct RunIslandTrailing: View {
    let state: RunActivityModel

    var body: some View {
        RunClockBlock(state: state, font: PulseFont.value(.title))
            .sessionActivityDark()
    }
}

/// Sous la Dynamic Island étendue : titre, distance, allure et le bouton.
struct RunIslandBottom: View {
    let state: RunActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RunTitleAndMetrics(state: state, spacing: 2)
            RunToggleButton(isPaused: state.isPaused)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sessionActivityDark()
    }
}

/// À droite de la Dynamic Island compacte : le temps (ou une icône de pause en pause).
struct RunCompactTime: View {
    let state: RunActivityModel

    var body: some View {
        Group {
            if state.isPaused {
                Image(systemName: "pause.fill")
                    .accessibilityLabel(RunActivityText.pausedTitle)
            } else {
                RunClockText(state: state)
                    .font(.caption.weight(.bold))
            }
        }
        .foregroundStyle(RunActivityStyle.accent)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 52, alignment: .trailing)
        .sessionActivityDark()
    }
}

/// La Dynamic Island minimale : l'icône de la course, ou de pause.
struct RunMinimalView: View {
    let state: RunActivityModel

    var body: some View {
        Image(systemName: state.isPaused ? "pause.fill" : "figure.run")
            .foregroundStyle(RunActivityStyle.accent)
            .accessibilityLabel(state.spokenLabel)
            .sessionActivityDark()
    }
}
