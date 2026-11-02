import PulseDomain
import WidgetFeature
import WidgetKit

struct LoadEntry: TimelineEntry {
    let date: Date
    let content: LoadWidgetContent
}

/// Lit les données de charge d'entraînement (ACWR) pour le petit widget Charge.
struct LoadTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LoadEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LoadEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LoadEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [LoadEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            LoadEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> LoadEntry {
        let now = Date.now
        return LoadEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
