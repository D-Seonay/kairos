import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Prochaine séance » : horaire, séance et allure/zone sur l'écran d'accueil.
struct NextWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NextWorkoutWidgetContent.kind, provider: NextWorkoutTimelineProvider()) { entry in
            NextWorkoutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(NextWorkoutWidgetContent.displayName)
        .description(NextWorkoutWidgetContent.summary)
        .supportedFamilies([.systemSmall])
    }
}

private struct NextWorkoutWidgetEntryView: View {
    let entry: NextWorkoutEntry

    var body: some View {
        NextWorkoutWidgetSmallView(content: entry.content)
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) {
                PulsePalette.surface
            }
    }
}

#Preview("Petit Prochaine séance", as: .systemSmall) {
    NextWorkoutWidget()
} timeline: {
    NextWorkoutEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
