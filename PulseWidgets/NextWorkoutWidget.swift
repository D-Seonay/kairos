import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Prochaine séance » : horaire, séance et allure/zone sur l'accueil et l'écran verrouillé.
struct NextWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NextWorkoutWidgetContent.kind, provider: NextWorkoutTimelineProvider()) { entry in
            NextWorkoutWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(NextWorkoutWidgetContent.displayName)
        .description(NextWorkoutWidgetContent.summary)
        .supportedFamilies([.systemSmall, .accessoryInline])
    }
}

private struct NextWorkoutWidgetEntryView: View {
    let entry: NextWorkoutEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label(entry.content.inlineText, systemImage: "figure.run")
                .accessibilityLabel(entry.content.accessibilityLabel)
        default:
            NextWorkoutWidgetSmallView(content: entry.content)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryInline:
            Color.clear
        default:
            PulsePalette.surface
        }
    }
}

#Preview("Petit Prochaine séance", as: .systemSmall) {
    NextWorkoutWidget()
} timeline: {
    NextWorkoutEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("En ligne Prochaine séance", as: .accessoryInline) {
    NextWorkoutWidget()
} timeline: {
    NextWorkoutEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
