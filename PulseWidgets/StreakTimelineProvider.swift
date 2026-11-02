import PulseDomain
import WidgetFeature
import WidgetKit

struct StreakEntry: TimelineEntry {
    let date: Date
    let content: StreakWidgetContent
}

/// Lit l'état de la série pour alimenter le widget Série sur l'écran d'accueil et l'écran verrouillé.
struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (StreakEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<StreakEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [StreakEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            StreakEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> StreakEntry {
        let now = Date.now
        return StreakEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
