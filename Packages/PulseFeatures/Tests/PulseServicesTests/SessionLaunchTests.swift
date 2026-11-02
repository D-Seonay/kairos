import Foundation
import PulseDomain
import PulseRecoveryEngine
import PulseServices
import Testing

struct SessionLaunchTests {
    private typealias Fix = LiveFixtures
    private let day = Fix.day([Fix.exercise(Fix.bench, order: 0, rpe: 8, rest: 120), Fix.exercise(Fix.pecDeck, order: 1, rpe: 8, rest: 60)])

    @Test func anAdjustedDayStartsAdjustedWithItsAdjustmentsApplied() {
        let launch = Fix.launch(day, .moderateFatigue)
        #expect(launch.title == "Push" && launch.day?.exercises[0].sets == 2 && launch.day?.exercises[0].restSeconds == 165)
        #expect(launch.applied.map(\.kind) == [.volume, .rpeCap, .rest] && launch.refused.isEmpty)
        #expect(!launch.policy.allowsIncrease)
    }

    @Test func theOriginalSessionRefusesTheCategoryAdjustments() {
        let launch = Fix.launch(day, .moderateFatigue, originalChosen: true)
        #expect(launch.day == day)
        #expect(launch.applied.isEmpty && launch.refused.map(\.kind) == [.volume, .rpeCap, .rest])
        #expect(!launch.policy.allowsIncrease)
    }

    @Test func aNormalOriginalSessionStillAllowsIncreases() {
        let launch = Fix.launch(day, .normal, originalChosen: true)
        #expect(launch.day == day && launch.applied.isEmpty && launch.refused.map(\.kind) == [.rest])
        #expect(launch.policy.allowsIncrease)
    }

    @Test func overreachedAlwaysStartsTheOriginalWithoutIncrease() {
        for chosen in [false, true] {
            let launch = Fix.launch(day, .overreached, originalChosen: chosen)
            #expect(launch.day == day && launch.applied.isEmpty && launch.refused.map(\.kind) == [.replaceWithMobility])
            #expect(!launch.policy.allowsIncrease)
        }
    }

    @Test func noScoreOrAdaptationOffKeepsTheDayAsPlanned() {
        let none = Fix.launch(day, nil)
        #expect(none.day == day && none.applied.isEmpty && none.refused.isEmpty && none.policy.allowsIncrease)
        var profile = UserProfile(createdAt: .t0, updatedAt: .t0)
        profile.adaptationEnabled = false
        let off = SessionLaunch.routine(day, programID: nil, recovery: Fix.recovery(.moderateFatigue), originalChosen: false,
                                        profile: profile)
        #expect(off.day == day && off.applied.isEmpty && off.refused.isEmpty && off.policy.allowsIncrease)
    }

    @Test func anEstimatedScoreAdjustsButBlocksIncreases() {
        let launch = SessionLaunch.routine(day, programID: nil, recovery: Fix.recovery(.normal, estimated: true),
                                           originalChosen: false, profile: nil)
        #expect(launch.applied.map(\.kind) == [.rest] && !launch.policy.allowsIncrease)
    }

    @Test func aFreeSessionHasNoDay() {
        let launch = SessionLaunch.free(policy: ProgressionPolicy(allowsIncrease: false))
        #expect(launch.title == "Séance libre" && launch.day == nil && launch.programID == nil)
        #expect(launch.applied.isEmpty && launch.refused.isEmpty && !launch.policy.allowsIncrease)
    }

    @Test func theProgramIsKept() {
        let programID = UUID()
        let launch = SessionLaunch.routine(day, programID: programID, recovery: nil, originalChosen: false, profile: nil)
        #expect(launch.programID == programID)
    }
}
