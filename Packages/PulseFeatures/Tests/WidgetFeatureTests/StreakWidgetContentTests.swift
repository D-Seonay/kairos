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
        #expect(content.accessibilityLabel.contains("14"))
    }

    @Test func labelsOfTheGallery() {
        #expect(StreakWidgetContent.kind == "StreakWidget")
        #expect(StreakWidgetContent.displayName == "Série")
        #expect(StreakWidgetContent.summary == "Ton rythme d'entraînement et ta régularité.")
    }
}
