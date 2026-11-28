import Foundation
import PulseDomain
import PulseRecoveryEngine
@testable import PulseServices
import Testing

struct HealthActivitiesTests {
    private let calendar = TestClock.calendar
    private let cache = InMemoryHealthSampleCache()
    private let profiles = InMemoryProfileRepository()

    private func workout(_ family: WorkoutFamily, at text: String, minutes: Double = 60, heartRate: Double? = nil,
                         bundle: String? = "com.apple.health", uuid: String = UUID().uuidString) -> CachedHealthSample {
        let start = TestClock.date(text)
        return CachedHealthSample(kind: .otherWorkout, start: start, end: start.addingTimeInterval(minutes * 60),
                                  value: Double(family.rawValue), averageHeartRate: heartRate, durationMinutes: minutes,
                                  healthKitUUID: uuid, sourceBundleID: bundle, fetchedAt: start)
    }

    @Test func eachFamilyHasItsDefaultRPE() {
        let samples = WorkoutFamily.allCases.map { workout($0, at: "2026-11-18T10:00") }
        let loads = HealthActivities.loadSessions(of: samples, ownBundleIdentifier: nil, birthDate: nil, calendar: calendar)
        #expect(loads.map(\.rpe) == [5, 7, 6, 6, 2, 3])
        #expect(loads.allSatisfy { $0.minutes == 60 && $0.date == TestClock.date("2026-11-18T10:00") })
    }

    @Test func theAverageHeartRateEstimatesTheRPE() {
        let sample = workout(.mobility, at: "2026-11-18T10:00", heartRate: 160)
        let loads = HealthActivities.loadSessions(of: [sample], ownBundleIdentifier: nil, birthDate: nil, calendar: calendar)
        let expected = EstimatedRPE.rpe(averageHeartRate: 160, maxHeartRate: EstimatedRPE.defaultMaxHeartRate)
        #expect(loads.first?.rpe == expected && expected != WorkoutFamily.mobility.defaultRPE)
    }

    @Test func anHourOfWalkingCountsLessThanAStrengthSession() {
        let samples = [workout(.walking, at: "2026-11-18T10:00"), workout(.strength, at: "2026-11-18T18:00")]
        let loads = HealthActivities.loadSessions(of: samples, ownBundleIdentifier: nil, birthDate: nil, calendar: calendar)
        #expect(loads.map { $0.minutes * $0.rpe } == [180, 360])
    }

    @Test func aBriskWalkWithHeartRateUsesIt() {
        let sample = workout(.walking, at: "2026-11-18T10:00", heartRate: 150)
        let loads = HealthActivities.loadSessions(of: [sample], ownBundleIdentifier: nil, birthDate: nil, calendar: calendar)
        let expected = EstimatedRPE.rpe(averageHeartRate: 150, maxHeartRate: EstimatedRPE.defaultMaxHeartRate)
        #expect(loads.first?.rpe == expected && expected != WorkoutFamily.walking.defaultRPE)
    }

    @Test func pulseOwnWorkoutsAreIgnored() {
        let samples = [workout(.strength, at: "2026-11-18T10:00", bundle: "fr.seonay.pulse"),
                       workout(.strength, at: "2026-11-18T18:00", bundle: "com.hevy")]
        let loads = HealthActivities.loadSessions(of: samples, ownBundleIdentifier: "fr.seonay.pulse", birthDate: nil,
                                                  calendar: calendar)
        #expect(loads.map(\.date) == [TestClock.date("2026-11-18T18:00")])
    }

    @Test func aWorkoutOverlappingARecordedSessionIsIgnored() {
        let start = TestClock.date("2026-11-18T18:00")
        let session = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3_600), kind: .strength, source: .pulse,
                                     status: .completed, title: "Push", createdAt: start, updatedAt: start)
        var planned = session
        planned.status = .inProgress
        let watch = workout(.strength, at: "2026-11-18T18:10", minutes: 45, bundle: "com.apple.health")
        let swim = workout(.endurance, at: "2026-11-18T07:00", bundle: "com.apple.health")
        let loads = HealthActivities.loadSessions(of: [watch, swim], excluding: [session], ownBundleIdentifier: nil, birthDate: nil,
                                                  calendar: calendar)
        #expect(loads.map(\.date) == [TestClock.date("2026-11-18T07:00")])
        let notDone = HealthActivities.loadSessions(of: [watch], excluding: [planned], ownBundleIdentifier: nil, birthDate: nil,
                                                    calendar: calendar)
        #expect(notDone.count == 1, "Une séance qui n'est ni terminée ni abandonnée n'écarte rien")
    }

    @Test func aWorkoutWithoutDurationUsesItsDatesAndAnEmptyOneIsSkipped() {
        var dated = workout(.endurance, at: "2026-11-18T10:00", minutes: 30)
        dated.durationMinutes = nil
        let empty = workout(.endurance, at: "2026-11-18T12:00", minutes: 0)
        let loads = HealthActivities.loadSessions(of: [dated, empty], ownBundleIdentifier: nil, birthDate: nil, calendar: calendar)
        #expect(loads.map(\.minutes) == [30])
    }

    @Test func theServiceReadsTheCacheWindowAndTheDays() async throws {
        let first = workout(.sports, at: "2026-11-10T19:00", uuid: "a")
        let second = workout(.endurance, at: "2026-11-18T07:00", uuid: "b")
        let own = workout(.strength, at: "2026-11-18T18:00", bundle: "fr.seonay.pulse", uuid: "c")
        try await cache.apply(HealthSampleChanges(kind: .otherWorkout, added: [first, second, own], deletedHealthKitUUIDs: [],
                                                  anchor: Data("a".utf8), isFullRead: true))
        let service = HealthActivities(cache: cache, profiles: profiles, calendar: calendar, ownBundleIdentifier: "fr.seonay.pulse")
        let loads = await service.loadSessions(from: TestClock.date("2026-11-15T00:00"), to: TestClock.date("2026-11-20T00:00"),
                                               excluding: [])
        #expect(loads.map(\.date) == [TestClock.date("2026-11-18T07:00")])
        let starts = await service.starts(from: TestClock.date("2026-11-01T00:00"), to: TestClock.date("2026-12-01T00:00"))
        #expect(starts == [TestClock.date("2026-11-10T19:00"), TestClock.date("2026-11-18T07:00")])
    }

    @Test func otherWorkoutsCountInTheLoadRatio() {
        let start = TestClock.date("2026-10-01T08:00")
        let now = TestClock.date("2026-11-20T12:00")
        let extra = [LoadSession(date: TestClock.date("2026-11-19T10:00"), minutes: 60, rpe: 7)]
        let without = TrainingLoad.acwr(sessions: [], historyStart: start, now: now, calendar: calendar)
        let with = TrainingLoad.acwr(sessions: [], extra: extra, historyStart: start, now: now, calendar: calendar)
        #expect((with?.acute ?? 0) > (without?.acute ?? 0))
    }
}
