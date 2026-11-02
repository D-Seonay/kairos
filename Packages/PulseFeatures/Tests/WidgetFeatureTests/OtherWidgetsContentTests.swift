import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct OtherWidgetsContentTests {
    private let calendar = WidgetClock.calendar
    private let now = WidgetClock.date("2026-11-02T09:00")

    @Test func weekWidgetSampleContent() {
        let content = WeekWidgetContent.sample(at: now, calendar: calendar)
        #expect(WeekWidgetContent.kind == "WeekWidget")
        #expect(WeekWidgetContent.displayName == "Cette semaine")
        #expect(content.badgeText == "3 sur 5")
        #expect(content.days.count == 7)
        #expect(content.todayTitle == "Pectoraux et triceps")
        #expect(content.acwrRatio == 1.12)
    }

    @Test func loadWidgetSampleContent() {
        let content = LoadWidgetContent.sample(at: now, calendar: calendar)
        #expect(LoadWidgetContent.kind == "LoadWidget")
        #expect(LoadWidgetContent.displayName == "Charge")
        #expect(content.ratio == 1.12)
        #expect(content.ratioText == "1,12")
        #expect(content.isOptimal)
    }

    @Test func nextWorkoutWidgetSampleContent() {
        let content = NextWorkoutWidgetContent.sample(at: now, calendar: calendar)
        #expect(NextWorkoutWidgetContent.kind == "NextWorkoutWidget")
        #expect(NextWorkoutWidgetContent.displayName == "Prochaine séance")
        #expect(content.timingText == "Demain · 8:00")
        #expect(content.activeZone == 2)
    }
}
