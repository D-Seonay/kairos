import PulseDomain
import WidgetFeature
import WidgetKit

struct WeekEntry: TimelineEntry {
    let date: Date
    let content: WeekWidgetContent
}

/// Lit les données de la semaine pour alimenter le grand widget Semaine.
struct WeekTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (WeekEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<WeekEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [WeekEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            WeekEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> WeekEntry {
        let now = Date.now
        return WeekEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
