import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

struct RunActivityTextTests {
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000008") ?? UUID()

    private func state(timerStart: Date? = Date(timeIntervalSince1970: 0), frozen: Int = 0, meters: Double? = 4_380,
                       pace: Int? = 332, isPaused: Bool = false) -> RunActivityState {
        RunActivityState(sessionID: sessionID, title: "Sortie facile", timerStart: timerStart, frozenElapsedSeconds: frozen,
                         distanceMeters: meters, averagePaceSecondsPerKm: pace, isPaused: isPaused)
    }

    @Test func distanceFormatsKilometres() {
        #expect(RunActivityText.distance(4_380) == "4,38 km")
        #expect(RunActivityText.distance(10_000) == "10,00 km")
        #expect(RunActivityText.distance(0) == "0,00 km")
        #expect(RunActivityText.distance(nil) == "—")
    }

    @Test func paceFormatsMinutesSeconds() {
        #expect(RunActivityText.pace(332) == "5'32\" /km")
        #expect(RunActivityText.pace(300) == "5'00\" /km")
        #expect(RunActivityText.pace(nil) == "—")
    }

    @Test func elapsedFormatsMinutesAndHours() {
        #expect(RunActivityText.elapsed(seconds: 0) == "0:00")
        #expect(RunActivityText.elapsed(seconds: 754) == "12:34")
        #expect(RunActivityText.elapsed(seconds: 3_725) == "1:02:05")
        #expect(RunActivityText.elapsed(seconds: -4) == "0:00")
    }

    @Test func fixedTexts() {
        #expect(RunActivityText.pausedTitle == "En pause")
        #expect(RunActivityText.pauseTitle == "Pause")
        #expect(RunActivityText.resumeTitle == "Reprendre")
        #expect(RunActivityText.pauseLabel == "Mettre la course en pause")
        #expect(RunActivityText.resumeLabel == "Reprendre la course")
    }

    @Test func spokenSummaryReadsUnitsInFull() {
        let summary = RunActivityText.spokenSummary(state(), elapsed: 1_450)
        #expect(summary.contains("kilomètres"))
        #expect(summary.contains("par kilomètre"))
        #expect(summary == "Course Sortie facile, 24 minutes 10, 4,4 kilomètres, 5 minutes 32 par kilomètre")
    }

    @Test func spokenSummaryMentionsThePause() {
        let summary = RunActivityText.spokenSummary(state(timerStart: nil, frozen: 600, isPaused: true), elapsed: 600)
        #expect(summary == "Course Sortie facile, en pause, 10 minutes, 4,4 kilomètres, 5 minutes 32 par kilomètre")
    }

    @Test func spokenSummarySkipsMissingValues() {
        #expect(RunActivityText.spokenSummary(state(meters: nil, pace: nil), elapsed: 45) == "Course Sortie facile, 45 secondes")
    }

    @Test func runningLabelLeavesTheTimeToTheSystemTimer() {
        #expect(RunActivityText.accessibilityLabel(state()) == "Course Sortie facile, 4,4 kilomètres, 5 minutes 32 par kilomètre")
        #expect(RunActivityText.accessibilityLabel(state(meters: nil, pace: nil)) == "Course Sortie facile")
    }

    @Test func pausedLabelReadsTheFrozenTime() {
        let paused = state(timerStart: nil, frozen: 600, isPaused: true)
        #expect(RunActivityText.accessibilityLabel(paused)
                == "Course Sortie facile, en pause, 10 minutes, 4,4 kilomètres, 5 minutes 32 par kilomètre")
    }
}
