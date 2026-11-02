import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Charge » : ratio de charge aiguë sur chronique (ACWR) sur l'écran d'accueil.
struct LoadWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LoadWidgetContent.kind, provider: LoadTimelineProvider()) { entry in
            LoadWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LoadWidgetContent.displayName)
        .description(LoadWidgetContent.summary)
        .supportedFamilies([.systemSmall])
    }
}

private struct LoadWidgetEntryView: View {
    let entry: LoadEntry

    var body: some View {
        LoadWidgetSmallView(content: entry.content)
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) {
                PulsePalette.surface
            }
    }
}

#Preview("Petit Charge", as: .systemSmall) {
    LoadWidget()
} timeline: {
    LoadEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
