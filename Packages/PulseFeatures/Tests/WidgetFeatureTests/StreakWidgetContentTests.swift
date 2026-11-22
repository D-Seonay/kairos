import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct StreakWidgetContentTests {
    @Test func streakWidgetContentSample() {
        let content = StreakWidgetContent.sample(at: WidgetClock.date("2026-11-02T09:00"), calendar: WidgetClock.calendar)
        #expect(content.streakWeeks == 14)
        #expect(content.completedThisWeek == 3)
        #expect(content.targetThisWeek == 5)
        #expect(content.weekDays.count == 7)
        #expect(content.weekDays[0] == .completed)
        #expect(content.weekDays[4] == .today)
        #expect(content.subtitle == "3 sur 5 cette semaine")
        #expect(content.inlineText == "14 sem. · 3/5")
        #expect(content.accessibilityLabel == "Série de 14 semaines, 3 séances sur 5 cette semaine. "
            + "Lundi fait, mardi fait, mercredi fait, jeudi repos, aujourd'hui vendredi, samedi à venir, dimanche repos")
    }

    @Test func spokenWeekNamesEachDayWithItsState() {
        let calendar = WidgetClock.calendar
        let monday = WidgetClock.date("2026-11-02T00:00")
        let dates = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday) ?? monday }
        let days: [StreakWidgetContent.DayState] = [.completed, .rest, .today, .upcoming, .upcoming, .rest, .rest]
        #expect(WidgetPlanningText.spokenWeek(days: days, dates: dates, calendar: calendar)
            == "Lundi fait, mardi repos, aujourd'hui mercredi, jeudi à venir, vendredi à venir, samedi repos, dimanche repos")
        #expect(WidgetPlanningText.spokenWeek(days: [.completed], dates: dates, calendar: calendar) == "")
    }

    @Test func spokenLabelCountsInWords() {
        let one = StreakWidgetContent.spokenLabel(weeks: 1, completed: 1, target: 4, week: "Lundi fait")
        #expect(one == "Série de 1 semaine, 1 séance sur 4 cette semaine. Lundi fait")
        let none = StreakWidgetContent.spokenLabel(weeks: 0, completed: 0, target: 3, week: "")
        #expect(none == "Série de 0 semaine, 0 séance sur 3 cette semaine")
    }

    @Test func labelsOfTheGallery() {
        #expect(StreakWidgetContent.kind == "StreakWidget")
        #expect(StreakWidgetContent.displayName == "Série")
        #expect(StreakWidgetContent.summary == "Ton rythme d'entraînement et ta régularité.")
    }
}
