import Foundation
import Testing
@testable import TodayFeature

struct MobilityTimerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func countsDownFromTwentyMinutes() {
        var timer = MobilityTimer()
        #expect(timer.remaining(at: start) == 1200)
        timer.start(at: start)
        #expect(timer.remaining(at: start.addingTimeInterval(65)) == 1135)
        #expect(MobilityTimer.clockText(1135) == "18:55")
    }

    @Test func pauseFreezesTheRemainingTime() {
        var timer = MobilityTimer()
        timer.start(at: start)
        timer.pause(at: start.addingTimeInterval(60))
        #expect(timer.remaining(at: start.addingTimeInterval(600)) == 1140)
        timer.start(at: start.addingTimeInterval(600))
        #expect(timer.remaining(at: start.addingTimeInterval(660)) == 1080)
    }

    @Test func endsAtZero() {
        var timer = MobilityTimer()
        timer.start(at: start)
        #expect(!timer.isOver(at: start.addingTimeInterval(1199)))
        #expect(timer.remaining(at: start.addingTimeInterval(1300)) == 0)
        #expect(timer.isOver(at: start.addingTimeInterval(1300)))
    }

    @Test func finishEndsAtOnce() {
        var timer = MobilityTimer()
        timer.start(at: start)
        timer.finish()
        #expect(timer.phase == .finished)
        #expect(timer.isOver(at: start))
        #expect(timer.remaining(at: start) == 0)
    }

    @Test func clockTexts() {
        #expect(MobilityTimer.clockText(1200) == "20:00")
        #expect(MobilityTimer.clockText(0.4) == "00:01")
        #expect(MobilityTimer.clockText(0) == "00:00")
    }

    @Test func guideHasFiveSteps() {
        let steps = MobilityGuide.steps
        #expect(steps.count == 5)
        let titles = ["Hanches", "Chevilles", "Colonne thoracique", "Épaules", "Respiration"]
        for (step, title) in zip(steps, titles) {
            #expect(step.hasPrefix(title))
        }
    }
}

struct MobilitySheetTests {
    @Test func spokenTextNamesMinutesAndSeconds() {
        #expect(MobilitySheet.spokenText(1135) == "Temps restant 18 minutes 55 secondes")
        #expect(MobilitySheet.spokenText(60) == "Temps restant 1 minute")
        #expect(MobilitySheet.spokenText(1) == "Temps restant 1 seconde")
        #expect(MobilitySheet.spokenText(0).hasPrefix("Temps restant 0 seconde"))
    }
}
