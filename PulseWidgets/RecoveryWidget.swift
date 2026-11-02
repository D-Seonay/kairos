import PulseDesignSystem
import PulseDomain
import SwiftUI
import WidgetFeature
import WidgetKit

/// Le widget « Récupération » : petit sur l'écran d'accueil, circulaire et en ligne sur l'écran verrouillé.
struct RecoveryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RecoveryWidgetContent.kind, provider: RecoveryTimelineProvider()) { entry in
            RecoveryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(RecoveryWidgetContent.displayName)
        .description(RecoveryWidgetContent.summary)
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

private struct RecoveryWidgetEntryView: View {
    let entry: RecoveryEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        content
            .widgetURL(AppLink.today.url)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            // La jauge est tout le widget : elle porte la teinte d'accent.
            RecoveryWidgetCircularView(content: entry.content)
                .widgetAccentable()
        case .accessoryInline:
            Label(entry.content.inlineText, systemImage: "heart.fill")
                .accessibilityLabel(entry.content.accessibilityLabel)
        default:
            // L'encre sur le fond opale en couleur ; en monochrome (En veille la nuit), le système teinte d'après la luminance.
            // Le texte reste dans le groupe par défaut (clair) : une teinte sombre choisie par l'utilisateur ne l'efface pas.
            RecoveryWidgetSmallView(content: entry.content)
                .foregroundStyle(renderingMode == .fullColor ? PulsePalette.opalInk : .primary)
        }
    }

    @ViewBuilder private var background: some View {
        switch family {
        case .systemSmall: PulsePalette.opal
        case .accessoryCircular: AccessoryWidgetBackground()
        default: Color.clear
        }
    }
}

#Preview("Petit", as: .systemSmall) {
    RecoveryWidget()
} timeline: {
    RecoveryEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("Circulaire", as: .accessoryCircular) {
    RecoveryWidget()
} timeline: {
    RecoveryEntry(date: .now, content: .sample(at: .now, calendar: .current))
}

#Preview("En ligne", as: .accessoryInline) {
    RecoveryWidget()
} timeline: {
    RecoveryEntry(date: .now, content: .sample(at: .now, calendar: .current))
}
