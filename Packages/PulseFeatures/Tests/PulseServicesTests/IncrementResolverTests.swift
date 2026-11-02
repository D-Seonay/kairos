import Foundation
import PulseDomain
import PulseServices
import Testing

struct IncrementResolverTests {
    private let directory = ExerciseDirectory(library: .bundled, userExercises: [])

    @Test func incrementPrefersTheSettingThenTheSmallerDefault() throws {
        let pushdown = try #require(directory.info(.content(id: "triceps-pushdown-cable")))
        let advanced = UserProfile(upperIncrementKg: 1.25, lowerIncrementKg: 2.5)
        #expect(IncrementResolver.increment(for: pushdown, settings: nil, profile: advanced) == 1.25)
        #expect(IncrementResolver.increment(for: pushdown, settings: nil, profile: UserProfile()) == 2.5)
        let cable = ExerciseSettings(exercise: pushdown.reference, incrementKg: 3.5, warmupSetCount: nil, createdAt: .t0, updatedAt: .t0)
        #expect(IncrementResolver.increment(for: pushdown, settings: cable, profile: advanced) == 3.5)
    }

    @Test func withoutProfileTheExerciseDefaultApplies() throws {
        let pushdown = try #require(directory.info(.content(id: "triceps-pushdown-cable")))
        #expect(IncrementResolver.increment(for: pushdown, settings: nil, profile: nil) == pushdown.defaultIncrementKg)
    }

    @Test func settingsWithoutIncrementFallBackToTheDefaults() throws {
        let pushdown = try #require(directory.info(.content(id: "triceps-pushdown-cable")))
        let warmupOnly = ExerciseSettings(exercise: pushdown.reference, warmupSetCount: 2, createdAt: .t0, updatedAt: .t0)
        let advanced = UserProfile(upperIncrementKg: 1.25, lowerIncrementKg: 2.5)
        #expect(IncrementResolver.increment(for: pushdown, settings: warmupOnly, profile: advanced) == 1.25)
    }

    @Test func lowerBodyUsesTheLowerIncrementAndOtherRegionsTheUpperOne() throws {
        var squat = try #require(directory.info(.content(id: "back-squat-barbell")))
        let profile = UserProfile(upperIncrementKg: 1, lowerIncrementKg: 2)
        squat.defaultIncrementKg = 5
        squat.region = .lower
        #expect(IncrementResolver.increment(for: squat, settings: nil, profile: profile) == 2)
        squat.region = .core
        #expect(IncrementResolver.increment(for: squat, settings: nil, profile: profile) == 1)
        squat.defaultIncrementKg = 0.5
        #expect(IncrementResolver.increment(for: squat, settings: nil, profile: profile) == 0.5)
    }
}
