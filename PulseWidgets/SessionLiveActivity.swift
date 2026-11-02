import ActivityKit
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetFeature
import WidgetKit

/// La Live Activity de la séance (spec M4 §15.3) : le repos et la série suivante sur l'écran verrouillé et dans la Dynamic Island,
/// le titre et la durée écoulée hors repos. Elle n'affiche rien d'autre que `ContentState` (spec M4 §15.4).
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PulseSessionAttributes.self) { context in
            SessionLockScreenView(state: context.model)
                .activityBackgroundTint(PulsePalette.liveBackground)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionIslandLeading(state: context.model)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SessionIslandTrailing(state: context.model)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionIslandBottom(state: context.model)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(SessionActivityStyle.accent)
                    .accessibilityHidden(true)
            } compactTrailing: {
                SessionCompactTime(state: context.model)
            } minimal: {
                SessionMinimalView(state: context.model)
            }
            .keylineTint(SessionActivityStyle.accent)
        }
    }
}

extension ActivityViewContext<PulseSessionAttributes> {
    /// L'état affiché : une activité périmée (fin du repos passée) est hors repos.
    fileprivate var model: SessionActivityModel {
        SessionActivityModel(content: state, isStale: isStale)
    }
}

#if DEBUG
extension PulseSessionAttributes {
    fileprivate static let preview = PulseSessionAttributes(sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID())
}

extension PulseSessionAttributes.ContentState {
    fileprivate static var resting: Self {
        Self(title: "Pectoraux et triceps", startedAt: .now.addingTimeInterval(-1_500),
             restStartedAt: .now.addingTimeInterval(-8), restEndsAt: .now.addingTimeInterval(112),
             nextSet: "Développé couché à la barre · série 2 · 70 kg × 5")
    }

    fileprivate static var working: Self {
        Self(title: "Pectoraux et triceps", startedAt: .now.addingTimeInterval(-1_500),
             nextSet: "Développé couché à la barre · série 2 · 70 kg × 5")
    }
}

#Preview("Verrouillé", as: .content, using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
}

#Preview("Étendue", as: .dynamicIsland(.expanded), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
}

#Preview("Minimale", as: .dynamicIsland(.minimal), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
}
#endif
