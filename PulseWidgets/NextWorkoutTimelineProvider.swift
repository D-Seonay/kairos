import PulseDomain
import WidgetFeature
import WidgetKit

struct NextWorkoutEntry: TimelineEntry {
    let date: Date
    let content: NextWorkoutWidgetContent
}

/// Lit la prochaine séance prévue pour alimenter le petit widget Prochaine séance.
struct NextWorkoutTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextWorkoutEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (NextWorkoutEntry) -> Void) {
        completion(context.isPreview ? sampleEntry() : entries(now: .now).first ?? sampleEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<NextWorkoutEntry>) -> Void) {
        completion(Timeline(entries: entries(now: .now), policy: .atEnd))
    }

    private func entries(now: Date) -> [NextWorkoutEntry] {
        let calendar = Calendar.current
        let snapshot = WidgetSnapshotFile.appGroup()?.read()
        return RecoveryWidgetTimeline.entryDates(now: now, calendar: calendar).map { date in
            NextWorkoutEntry(date: date, content: .make(snapshot: snapshot, at: date, calendar: calendar))
        }
    }

    private func sampleEntry() -> NextWorkoutEntry {
        let now = Date.now
        return NextWorkoutEntry(date: now, content: .sample(at: now, calendar: .current))
    }
}
