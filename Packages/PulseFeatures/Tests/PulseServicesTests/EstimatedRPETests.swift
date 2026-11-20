import Foundation
import PulseServices
import Testing

struct EstimatedRPETests {
    @Test func tanakaMaxHeartRate() {
        let calendar = TestClock.calendar
        let birth = TestClock.date("1996-11-20T00:00")
        #expect(EstimatedRPE.maxHeartRate(birthDate: birth, at: TestClock.date("2026-11-20T08:00"), calendar: calendar) == 187)
        #expect(EstimatedRPE.maxHeartRate(birthDate: nil, at: .now, calendar: calendar) == 190)
    }

    @Test func rpeFollowsTheShareOfMaxHeartRate() {
        #expect(EstimatedRPE.rpe(averageHeartRate: 90, maxHeartRate: 200) == 2)
        #expect(EstimatedRPE.rpe(averageHeartRate: 110, maxHeartRate: 200) == 2.5)
        #expect(EstimatedRPE.rpe(averageHeartRate: 120, maxHeartRate: 200) == 3)
        #expect(EstimatedRPE.rpe(averageHeartRate: 140, maxHeartRate: 200) == 5)
        #expect(EstimatedRPE.rpe(averageHeartRate: 160, maxHeartRate: 200) == 7)
        #expect(EstimatedRPE.rpe(averageHeartRate: 185, maxHeartRate: 200) == 9.5)
        #expect(EstimatedRPE.rpe(averageHeartRate: 195, maxHeartRate: 200) == 10)
    }

    @Test func noHeartRateNoRPE() {
        #expect(EstimatedRPE.rpe(averageHeartRate: nil, maxHeartRate: 190) == nil)
        #expect(EstimatedRPE.rpe(averageHeartRate: 0, maxHeartRate: 190) == nil)
    }
}
