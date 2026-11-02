import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Charge » : ratio de charge aiguë sur chronique (ACWR) sur l'accueil et l'écran verrouillé.
struct LoadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LoadWidgetContent.kind, provider: LoadTimelineProvider()) { entry in
            LoadWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LoadWidgetContent.displayName)
        .description(LoadWidgetContent.summary)
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

private struct LoadWidgetEntryView: View {
    let entry: LoadEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            LoadWidgetCircularView(content: entry.content)
                .widgetAccentable()
        default:
            LoadWidgetSmallView(content: entry.content)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular:
            AccessoryWidgetBackground()
        default:
            PulsePalette.surface
        }
    }
}

#Preview("Petit Charge", as: .systemSmall) {
    LoadWidget()
} timeline: {
    LoadEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("Circulaire Charge", as: .accessoryCircular) {
    LoadWidget()
} timeline: {
    LoadEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
