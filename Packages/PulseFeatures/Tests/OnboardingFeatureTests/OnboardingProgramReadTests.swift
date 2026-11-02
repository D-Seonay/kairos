import Foundation
import OnboardingFeature
import PulseDomain
import PulseServices
import Testing

@MainActor
struct OnboardingProgramReadTests {
    @Test func anUnreadableProgramKeepsTheAdjustmentsAlreadyStoredForTheDay() async throws {
        let programs = FlakyProgramRepository()
        let recovery = InMemoryRecoveryRepository(calendar: OnboardingClock.calendar)
        let fixture = OnboardingFixture(scenario: .badNight, programs: programs, recovery: recovery)
        let model = fixture.makeModel()
        await OnboardingFixture.adoptRecommended(model)
        let day = OnboardingClock.calendar.startOfDay(for: OnboardingClock.now)
        let end = try #require(OnboardingClock.calendar.date(byAdding: .day, value: 1, to: day))
        let stored = try #require(try await recovery.dailyRecoveries(from: day, to: end).first)
        #expect(!stored.adjustments.isEmpty)

        await programs.setFailsOnRead(true)
        await model.runCalibration()

        let after = try #require(try await recovery.dailyRecoveries(from: day, to: end).first)
        #expect(after.adjustments == stored.adjustments)
    }
}
