import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le grand widget « Cette semaine » : planning, séance du jour, charge d'entraînement et séance de demain.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WeekWidgetContent.kind, provider: WeekTimelineProvider()) { entry in
            WeekWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WeekWidgetContent.displayName)
        .description(WeekWidgetContent.summary)
        .supportedFamilies([.systemLarge])
    }
}

private struct WeekWidgetEntryView: View {
    let entry: WeekEntry

    var body: some View {
        WeekWidgetLargeView(content: entry.content)
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) {
                PulsePalette.surface
            }
    }
}

#Preview("Grand Semaine", as: .systemLarge) {
    WeekWidget()
} timeline: {
    WeekEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
