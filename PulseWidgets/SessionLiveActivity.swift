import ActivityKit
import PulseDesignSystem
import PulseLiveActivity
import SwiftUI
import WidgetFeature
import WidgetKit

/// La Live Activity de la séance (spec M4 §15.3) : le repos et la série suivante sur l'écran verrouillé et dans la Dynamic Island,
/// le titre et la durée écoulée hors repos, et la progression des séries de travail tout du long. Elle n'affiche rien d'autre que
/// `ContentState` (spec M4 §15.4).
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
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    SessionIslandTrailing(state: context.model)
                }
                DynamicIslandExpandedRegion(.center) {
                    SessionIslandCenter(state: context.model)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionIslandBottom(state: context.model)
                }
            } compactLeading: {
                SessionCompactLeading(state: context.model)
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
             nextSet: "Développé couché à la barre · série 2 · 70 kg × 5", doneSets: 4, plannedSets: 15)
    }

    fileprivate static var working: Self {
        Self(title: "Pectoraux et triceps", startedAt: .now.addingTimeInterval(-1_500),
             nextSet: "Développé couché à la barre · série 2 · 70 kg × 5", nextSetID: UUID(), doneSets: 4, plannedSets: 15)
    }

    fileprivate static var free: Self {
        Self(title: "Séance libre", startedAt: .now.addingTimeInterval(-300))
    }
}

#Preview("Verrouillé, accessibilité 3") {
    SessionLockScreenView(state: SessionActivityModel(content: .resting, isStale: false))
        .background(PulsePalette.liveBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Verrouillé hors repos, accessibilité 3") {
    SessionLockScreenView(state: SessionActivityModel(content: .working, isStale: false))
        .background(PulsePalette.liveBackground)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Verrouillé, apparence claire du système") {
    SessionLockScreenView(state: SessionActivityModel(content: .resting, isStale: false))
        .background(PulsePalette.liveBackground)
        .environment(\.colorScheme, .light)
}

#Preview("Verrouillé", as: .content, using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
    PulseSessionAttributes.ContentState.free
}

#Preview("Compact", as: .dynamicIsland(.compact), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
    PulseSessionAttributes.ContentState.free
}

#Preview("Étendue", as: .dynamicIsland(.expanded), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
    PulseSessionAttributes.ContentState.free
}

#Preview("Minimale", as: .dynamicIsland(.minimal), using: PulseSessionAttributes.preview) {
    SessionLiveActivity()
} contentStates: {
    PulseSessionAttributes.ContentState.resting
    PulseSessionAttributes.ContentState.working
    PulseSessionAttributes.ContentState.free
}
#endif
