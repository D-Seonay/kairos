import PulseDomain
import WidgetFeature
import WidgetKit

struct RecoveryEntry: TimelineEntry {
    let date: Date
    let content: RecoveryWidgetContent
}

/// Lit l'instantané du groupe d'apps à chaque timeline : l'app le réécrit après chaque synchro et recharge le widget.
/// Les dates viennent de l'entrée de timeline, le calendrier est celui de l'appareil (seule exception à l'horloge injectée).
struct RecoveryTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecoveryEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (RecoveryEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<RecoveryEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [RecoveryEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            RecoveryEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> RecoveryEntry {
        let now = Date.now
        return RecoveryEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
