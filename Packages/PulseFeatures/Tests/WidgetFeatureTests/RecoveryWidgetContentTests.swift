import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct RecoveryWidgetContentTests {
    private func content(_ snapshot: WidgetSnapshot?, at text: String = "2026-11-02T09:00") -> RecoveryWidgetContent {
        RecoveryWidgetContent.make(snapshot: snapshot, at: WidgetClock.date(text), calendar: WidgetClock.calendar)
    }

    @Test func todaySnapshotShowsScoreAndSession() {
        let content = content(WidgetSample.snapshot())
        #expect(content.score == 58)
        #expect(content.category == .moderateFatigue)
        #expect(content.categoryText == "Fatigue modérée")
        #expect(content.footer == "Séance allégée")
        #expect(content.inlineText == "58 · fatigue modérée")
        #expect(content.accessibilityLabel == "Récupération 58 sur 100, fatigue modérée, séance allégée")
    }

    @Test func normalSessionFooter() {
        let content = content(WidgetSample.snapshot(isLightened: false))
        #expect(content.footer == "Séance normale")
        #expect(content.accessibilityLabel == "Récupération 58 sur 100, fatigue modérée, séance normale")
    }

    @Test func noSessionFooter() {
        let content = content(WidgetSample.snapshot(sessionTitle: nil, isLightened: false))
        #expect(content.footer == "Pas de séance aujourd'hui")
        #expect(content.accessibilityLabel == "Récupération 58 sur 100, fatigue modérée, pas de séance aujourd'hui")
    }

    @Test func estimatedIsSaid() {
        let content = content(WidgetSample.snapshot(isEstimated: true))
        #expect(content.categoryText == "Fatigue modérée · estimé")
        #expect(content.accessibilityLabel.contains("estimé"))
    }

    @Test func yesterdaysSnapshotIsNotShownAsToday() {
        let content = content(WidgetSample.snapshot(), at: "2026-11-03T02:00")
        #expect(content.score == nil)
        #expect(content.category == nil)
        #expect(content.categoryText == "Score pas encore prêt")
        #expect(content.inlineText == "Score pas encore prêt")
        #expect(content.footer == nil)
        #expect(content.accessibilityLabel == "Récupération : score pas encore prêt")
    }

    @Test func missingSnapshotShowsPlaceholder() {
        let content = content(nil)
        #expect(content.score == nil)
        #expect(content.category == nil)
        #expect(content.categoryText == "Score pas encore prêt")
        #expect(content.footer == nil)
        #expect(content.accessibilityLabel == "Récupération : score pas encore prêt")
    }

    @Test func labelsOfTheGallery() {
        #expect(RecoveryWidgetContent.kind == "RecoveryWidget")
        #expect(RecoveryWidgetContent.displayName == "Récupération")
        #expect(RecoveryWidgetContent.summary == "Ton score du matin et ta séance du jour.")
    }

    @Test func timelineChangesAtNextMidnight() {
        let now = WidgetClock.date("2026-10-24T22:00")
        let dates = RecoveryWidgetTimeline.entryDates(now: now, calendar: WidgetClock.calendar)
        #expect(dates == [now, WidgetClock.date("2026-10-25T00:00")])
    }
}
