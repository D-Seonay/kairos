import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Série » : petit sur l'écran d'accueil, circulaire et en ligne sur l'écran verrouillé.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: StreakWidgetContent.kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(StreakWidgetContent.displayName)
        .description(StreakWidgetContent.summary)
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

private struct StreakWidgetEntryView: View {
    let entry: StreakEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            StreakWidgetCircularView(content: entry.content)
                .widgetAccentable()
        case .accessoryInline:
            Label(entry.content.inlineText, systemImage: "flame.fill")
                .accessibilityLabel(entry.content.accessibilityLabel)
        default:
            let amber = PulsePalette.accent(for: .amber)
            StreakWidgetSmallView(content: entry.content)
                .foregroundStyle(renderingMode == .fullColor ? Color(amber.accentInk) : .primary)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .systemSmall:
            let amber = PulsePalette.accent(for: .amber)
            LinearGradient(
                colors: [Color(amber.accent2), Color(amber.accent)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .accessoryCircular:
            AccessoryWidgetBackground()
        default:
            Color.clear
        }
    }
}

#Preview("Petit Streak", as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("Circulaire Streak", as: .accessoryCircular) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("En ligne Streak", as: .accessoryInline) {
    StreakWidget()
} timeline: {
    StreakEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
