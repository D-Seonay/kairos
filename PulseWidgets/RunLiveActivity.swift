import ActivityKit
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetKit

/// La Live Activity de la course : le temps, la distance GPS filtrée et l'allure moyenne sur l'écran verrouillé et dans la Dynamic
/// Island, avec Pause et Reprendre. Elle n'affiche rien d'autre que `ContentState`, jamais de fréquence cardiaque.
struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseRunAttributes.self) { context in
            RunLockScreenView(state: context.model)
                .activityBackgroundTint(PulsePalette.liveBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RunIslandLeading()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RunIslandTrailing(state: context.model)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RunIslandBottom(state: context.model)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(RunActivityStyle.accent)
                    .accessibilityHidden(true)
            } compactTrailing: {
                RunCompactTime(state: context.model)
            } minimal: {
                RunMinimalView(state: context.model)
            }
            .keylineTint(RunActivityStyle.accent)
        }
    }
}

extension ActivityViewContext<PulseRunAttributes> {
    fileprivate var model: RunActivityModel {
        RunActivityModel(sessionID: attributes.sessionID, content: state)
    }
}

#if DEBUG
extension PulseRunAttributes {
    fileprivate static let preview = PulseRunAttributes(sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID())
}

extension PulseRunAttributes.ContentState {
    fileprivate static var running: Self {
        Self(title: "Sortie facile", timerStart: .now.addingTimeInterval(-1_450), distanceMeters: 4_380, averagePaceSecondsPerKm: 332)
    }

    fileprivate static var paused: Self {
        Self(title: "Sortie facile", frozenElapsedSeconds: 1_450, distanceMeters: 4_380, averagePaceSecondsPerKm: 332, isPaused: true)
    }
}

#Preview("Verrouillé, accessibilité 3") {
    RunLockScreenView(state: RunActivityModel(sessionID: UUID(), content: .paused))
        .background(PulsePalette.liveBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Verrouillé", as: .content, using: PulseRunAttributes.preview) {
    RunLiveActivity()
} contentStates: {
    PulseRunAttributes.ContentState.running
    PulseRunAttributes.ContentState.paused
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PulseRunAttributes.preview) {
    RunLiveActivity()
} contentStates: {
    PulseRunAttributes.ContentState.running
    PulseRunAttributes.ContentState.paused
}

#Preview("Étendue", as: .dynamicIsland(.expanded), using: PulseRunAttributes.preview) {
    RunLiveActivity()
} contentStates: {
    PulseRunAttributes.ContentState.running
    PulseRunAttributes.ContentState.paused
}

#Preview("Minimale", as: .dynamicIsland(.minimal), using: PulseRunAttributes.preview) {
    RunLiveActivity()
} contentStates: {
    PulseRunAttributes.ContentState.running
    PulseRunAttributes.ContentState.paused
}
#endif
