import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Séance du jour » : moyen sur l'accueil, rectangulaire et en ligne sur l'écran verrouillé.
struct TodaySessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodaySessionWidgetContent.kind, provider: TodaySessionTimelineProvider()) { entry in
            TodaySessionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(TodaySessionWidgetContent.displayName)
        .description(TodaySessionWidgetContent.summary)
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct TodaySessionWidgetEntryView: View {
    let entry: TodaySessionEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            TodaySessionWidgetRectangularView(content: entry.content)
        case .accessoryInline:
            Label(entry.content.inlineText, systemImage: entry.content.isRest ? "bed.double.fill" : "dumbbell.fill")
                .accessibilityLabel(entry.content.accessibilityLabel)
        default:
            TodaySessionWidgetMediumView(content: entry.content)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch family {
        case .systemMedium:
            PulsePalette.surface
        case .accessoryRectangular:
            AccessoryWidgetBackground()
        default:
            Color.clear
        }
    }
}

#Preview("Moyen Séance", as: .systemMedium) {
    TodaySessionWidget()
} timeline: {
    TodaySessionEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("Rectangulaire Séance", as: .accessoryRectangular) {
    TodaySessionWidget()
} timeline: {
    TodaySessionEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("En ligne Séance", as: .accessoryInline) {
    TodaySessionWidget()
} timeline: {
    TodaySessionEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
