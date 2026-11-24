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
        #expect(content.accessibilityLabel == "Série de 6 semaines, 1 séance sur 4 cette semaine. "
            + "Lundi fait, mardi repos, aujourd'hui mercredi, à venir, jeudi à venir, vendredi à venir, samedi repos, dimanche repos")
    }

    /// Un instantané d'un autre jour, ou aucun : les widgets disent qu'ils ne sont pas prêts, jamais l'exemple de la galerie.
    @Test func aSnapshotOfAnotherDayIsNotShownAsReal() {
        let stale = snapshot(day: "2026-11-03T00:00")
        let streak = StreakWidgetContent.make(snapshot: stale, at: now, calendar: calendar)
        #expect(streak == .notReady && streak != .sample(at: now, calendar: calendar))
        #expect(!streak.isReady && streak.weeksText == "—" && streak.weekDays.isEmpty)
        #expect(streak.accessibilityLabel == "Série pas encore prête. Ouvre Pulse pour la mettre à jour")

        let week = WeekWidgetContent.make(snapshot: nil, at: now, calendar: calendar)
        #expect(week != .sample(at: now, calendar: calendar))
        #expect(week.days.map(\.letter) == ["L", "M", "M", "J", "V", "S", "D"])
        #expect(week.days.map(\.state) == [.upcoming, .upcoming, .today, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(week.badgeText == "—" && week.todayTitle == "Pas encore prête" && week.todayMuscleLevels.isEmpty)
        #expect(week.accessibilityLabel == "Cette semaine : pas encore prête. Ouvre Pulse pour la mettre à jour")

        let next = NextWorkoutWidgetContent.make(snapshot: stale, at: now, calendar: calendar)
        #expect(next == .notReady && next.title == "Pas encore prête" && next.activeZone == 0)

        let load = LoadWidgetContent.make(snapshot: nil, at: now, calendar: calendar)
        #expect(load == .notReady && load.ratioText == "—" && load.zoneText == "Ouvre Pulse" && !load.isOptimal)
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

    @Test func weekFollowsTheSnapshotFigure() {
        var male = snapshot()
        male.muscleMapFigure = .male
        #expect(WeekWidgetContent.make(snapshot: male, at: now, calendar: calendar).muscleMapFigure == .male)
        #expect(WeekWidgetContent.make(snapshot: snapshot(), at: now, calendar: calendar).muscleMapFigure == .female)
    }

    @Test func weekSpeaksTheDaysWithoutMiddleDot() {
        let content = WeekWidgetContent.make(snapshot: snapshot(), at: now, calendar: calendar)
        #expect(content.accessibilityLabel == "Cette semaine : 1 séance faite sur 4. "
            + "Lundi fait, mardi repos, aujourd'hui mercredi, à venir, jeudi à venir, vendredi à venir, samedi repos, dimanche repos. "
            + "Aujourd'hui : Legs. Charge 1,62, risque de blessure. Demain, Fractionné")
        #expect(!content.accessibilityLabel.contains("·"))
        let sample = WeekWidgetContent.sample(at: now, calendar: calendar)
        #expect(sample.accessibilityLabel.contains("Lundi fait, mardi fait, mercredi fait, jeudi repos, aujourd'hui vendredi"))
        #expect(sample.accessibilityLabel.contains("Charge 1,12, zone optimale."))
        #expect(!sample.accessibilityLabel.contains("·"))
    }

    @Test func weekWithoutLoadOrNextSessionStaysSpoken() {
        let bare = WidgetSnapshot(day: WidgetClock.date("2026-11-04T00:00"), score: 72, category: .normal, isEstimated: false,
                                  sessionTitle: nil, isLightened: false, streak: WidgetStreak(weeks: 6, completed: 1, target: 4),
                                  week: snapshot().week, nextSession: nil, loadRatio: nil)
        let content = WeekWidgetContent.make(snapshot: bare, at: now, calendar: calendar)
        #expect(content.accessibilityLabel.hasSuffix("Aujourd'hui : Jour de repos. Charge après 28 jours. Rien de prévu cette semaine"))
    }

    @Test func spokenPaceReadsTheRangeInWords() {
        #expect(WidgetPlanningText.spokenPace(fastest: 345, slowest: 365) == "5 minutes 45 à 6 minutes 5 par kilomètre")
        #expect(WidgetPlanningText.spokenPace(fastest: 300, slowest: 330) == "5 minutes à 5 minutes 30 par kilomètre")
    }

    @Test func spokenDetailReadsSeparatorsAndUnits() {
        #expect(WidgetPlanningText.spokenDetail("Sortie facile · 45 min") == "Sortie facile, 45 minutes")
        #expect(WidgetPlanningText.spokenDetail("Course · 1 min") == "Course, 1 minute")
        #expect(WidgetPlanningText.spokenDetail("Sortie longue · 12,5 km") == "Sortie longue, 12,5 kilomètres")
        #expect(WidgetPlanningText.spokenDetail("Sortie · 1 km") == "Sortie, 1 kilomètre")
        #expect(WidgetPlanningText.spokenDetail("Sortie · 1,5 km") == "Sortie, 1,5 kilomètre")
        #expect(WidgetPlanningText.spokenDetail("Sortie · 2 km") == "Sortie, 2 kilomètres")
        #expect(WidgetPlanningText.spokenDetail("Sortie · 1,9 km") == "Sortie, 1,9 kilomètre")
        // Dit d'après la valeur arrondie à une décimale : « 2 kilomètres », jamais « 2 kilomètre ».
        #expect(WidgetPlanningText.spokenDetail("Sortie · 1,99 km") == "Sortie, 2 kilomètres")
        #expect(WidgetPlanningText.spokenDetail("5 exercices · 16 séries") == "5 exercices, 16 séries")
        #expect(WidgetPlanningText.spokenDetail("1 exercice · 1 série") == "1 exercice, 1 série")
    }

    @Test func nextWorkoutSpeaksWithoutSeparatorsOrAbbreviations() {
        let run = WidgetNextSession(title: "Endurance", date: WidgetClock.date("2026-11-07T00:00"), kind: .run,
                                    detail: "Sortie facile · 45 min")
        let content = NextWorkoutWidgetContent.make(snapshot: snapshot(next: run), at: now, calendar: calendar)
        #expect(content.accessibilityLabel == "Prochaine séance : Samedi, Endurance, Sortie facile, 45 minutes")
    }

    @Test func nextWorkoutWithoutDetailHasNoTrailingComma() {
        let bare = WidgetNextSession(title: "Push", date: WidgetClock.date("2026-11-07T00:00"), kind: .strength, detail: nil)
        let content = NextWorkoutWidgetContent.make(snapshot: snapshot(next: bare), at: now, calendar: calendar)
        #expect(content.accessibilityLabel == "Prochaine séance : Samedi, Push")
        #expect(NextWorkoutWidgetContent.spokenLabel(timing: "Demain", title: "Push", detail: "") == "Prochaine séance : Demain, Push")
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
        #expect(early.ratioText == "—" && early.zoneText == "Après 28 jours" && !early.isOptimal)
    }
}
