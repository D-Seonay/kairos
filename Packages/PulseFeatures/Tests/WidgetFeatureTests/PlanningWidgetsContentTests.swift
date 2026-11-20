import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

/// Les widgets Série, Semaine, Prochaine séance et Charge sur l'instantané réel (spec M6 §11). Mercredi 4 novembre 2026.
struct PlanningWidgetsContentTests {
    private let calendar = WidgetClock.calendar
    private let now = WidgetClock.date("2026-11-04T09:00")

    private func snapshot(loadRatio: Double? = 1.62, next: WidgetNextSession? = nil, day: String = "2026-11-04T00:00") -> WidgetSnapshot {
        let states: [(WidgetDayKind, WidgetDayState)] = [(.strength, .done), (.run, .missed), (.strength, .planned), (.run, .planned),
                                                         (.strength, .planned), (.rest, .rest), (.rest, .rest)]
        let week = states.enumerated().map { index, entry in
            WidgetDay(date: WidgetClock.date(String(format: "2026-11-%02dT00:00", 2 + index)), kind: entry.0, state: entry.1,
                      isToday: index == 2)
        }
        let nextSession = next ?? WidgetNextSession(title: "Fractionné", date: WidgetClock.date("2026-11-05T00:00"), kind: .run,
                                                    detail: "Fractionné · 40 min")
        return WidgetSnapshot(day: WidgetClock.date(day), score: 72, category: .normal, isEstimated: false, sessionTitle: "Legs",
                              isLightened: false, streak: WidgetStreak(weeks: 6, completed: 1, target: 4), week: week,
                              nextSession: nextSession, loadRatio: loadRatio)
    }

    @Test func streakReadsTheWeekWithoutBlame() {
        let content = StreakWidgetContent.make(snapshot: snapshot(), at: now, calendar: calendar)
        #expect(content.streakWeeks == 6 && content.completedThisWeek == 1 && content.targetThisWeek == 4)
        #expect(content.weekDays == [.completed, .rest, .today, .upcoming, .upcoming, .rest, .rest])
        #expect(content.subtitle == "1 sur 4 cette semaine")
    }

    @Test func aSnapshotOfAnotherDayFallsBackToTheSample() {
        let stale = snapshot(day: "2026-11-03T00:00")
        #expect(StreakWidgetContent.make(snapshot: stale, at: now, calendar: calendar) == .sample(at: now, calendar: calendar))
        #expect(WeekWidgetContent.make(snapshot: nil, at: now, calendar: calendar) == .sample(at: now, calendar: calendar))
    }

    @Test func weekShowsTodayTheLoadAndTomorrow() {
        let content = WeekWidgetContent.make(snapshot: snapshot(), at: now, calendar: calendar)
        #expect(content.days.map(\.letter) == ["L", "M", "M", "J", "V", "S", "D"])
        #expect(content.days.map(\.iconName) == ["dumbbell.fill", "figure.run", "dumbbell.fill", "figure.run", "dumbbell.fill", "minus",
                                                 "minus"])
        #expect(content.badgeText == "1 sur 4" && content.todayTitle == "Legs" && content.todayMeta == "Comme prévu")
        #expect(content.acwrRatio == 1.62 && content.acwrZoneText == "1,62 · risque de blessure")
        #expect(content.tomorrowText == "Demain : Fractionné")
    }

    @Test func nextWorkoutNamesTheDay() {
        let saturday = WidgetNextSession(title: "Push", date: WidgetClock.date("2026-11-07T00:00"), kind: .strength,
                                         detail: "5 exercices · 16 séries")
        let content = NextWorkoutWidgetContent.make(snapshot: snapshot(next: saturday), at: now, calendar: calendar)
        #expect(content.timingText == "Samedi" && content.title == "Push" && content.zoneText == "5 exercices · 16 séries")
        #expect(content.inlineText == "Push · Samedi")
    }

    @Test func loadSaysWhenTheRatioIsNotReady() {
        let ready = LoadWidgetContent.make(snapshot: snapshot(loadRatio: 1.1), at: now, calendar: calendar)
        #expect(ready.ratioText == "1,1" && ready.zoneText == "Zone optimale" && ready.isOptimal)
        let early = LoadWidgetContent.make(snapshot: snapshot(loadRatio: nil), at: now, calendar: calendar)
        #expect(early.ratioText == "–" && early.zoneText == "Après 28 jours" && !early.isOptimal)
    }
}
