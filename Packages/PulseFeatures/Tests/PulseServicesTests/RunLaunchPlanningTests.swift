import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct RunLaunchPlanningTests {
    private let programID = UUID()

    private func day(_ type: RunType, minutes: Int? = nil, km: Double? = nil) -> RoutineDay {
        RoutineDay(order: 2, name: "Course du jeudi", kind: .run, runType: type, runTargetMinutes: minutes, runTargetKm: km)
    }

    @Test func plannedRunKeepsTypeTargetAndOrigin() {
        let planned = day(.long, km: 12)
        let launch = RunLaunch.planned(planned, programID: programID, adjusted: nil)
        #expect(launch.title == "Sortie longue")
        #expect(launch.runType == .long)
        #expect(launch.targetKm == 12)
        #expect(launch.targetMinutes == nil)
        #expect(launch.programID == programID)
        #expect(launch.routineDayID == planned.id)
        #expect(launch.adjustmentNote == nil)
    }

    @Test func untypedDayIsTitledByItsName() {
        let planned = RoutineDay(order: 0, name: "Footing du matin", kind: .run, runTargetMinutes: 30)
        #expect(RunLaunch.planned(planned, programID: nil, adjusted: nil).title == "Footing du matin")
    }

    @Test func swappedIntervalsBecomeEasy() {
        let planned = day(.intervals, minutes: 40)
        let adjusted = AdjustedSession(day: planned, adjustments: [SessionAdjustment(kind: .swapIntervalsForEasy, reason: "Fatigue")])
        let launch = RunLaunch.planned(planned, programID: programID, adjusted: adjusted)
        #expect(launch.runType == .easy)
        #expect(launch.title == "Sortie facile")
        #expect(launch.adjustmentNote == "au lieu du fractionné")
        #expect(launch.targetMinutes == 40)
        #expect(launch.routineDayID == planned.id)
    }

    @Test func suggestRestKeepsTheTarget() {
        let planned = day(.intervals, minutes: 35)
        let adjusted = AdjustedSession(day: planned, adjustments: [SessionAdjustment(kind: .suggestRest, reason: "Surmenage")])
        let launch = RunLaunch.planned(planned, programID: programID, adjusted: adjusted)
        #expect(launch.runType == .intervals)
        #expect(launch.title == "Fractionné")
        #expect(launch.targetMinutes == 35)
        #expect(launch.adjustmentNote == "repos conseillé aujourd'hui")
    }

    @Test func adjustmentWithoutRunChangeAddsNoNote() {
        let planned = day(.easy, minutes: 30)
        let launch = RunLaunch.planned(planned, programID: programID, adjusted: AdjustedSession(day: planned))
        #expect(launch.runType == .easy)
        #expect(launch.adjustmentNote == nil)
    }

    @Test func freeRunHasNoTarget() {
        let launch = RunLaunch.free()
        #expect(launch.title == "Course libre")
        #expect(launch.runType == nil)
        #expect(launch.targetMinutes == nil)
        #expect(launch.targetKm == nil)
        #expect(launch.programID == nil)
        #expect(launch.routineDayID == nil)
        #expect(launch.targetProgress(movingSeconds: 600, distanceMeters: 2_000) == nil)
    }
}
