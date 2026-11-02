import PulseDomain
import WidgetFeature
import WidgetKit

struct TodaySessionEntry: TimelineEntry {
    let date: Date
    let content: TodaySessionWidgetContent
}

/// Lit l'instantané pour alimenter le widget Séance du jour sur l'écran d'accueil et l'écran verrouillé.
struct TodaySessionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaySessionEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodaySessionEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodaySessionEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [TodaySessionEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            TodaySessionEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> TodaySessionEntry {
        let now = Date.now
        return TodaySessionEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
