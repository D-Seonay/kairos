import Foundation
import PulseDomain
import PulseServices
import Testing

struct HabitualBedtimeTests {
    private typealias Fixture = SupplementFixtures
    private let calendar = TestClock.calendar
    private let now = TestClock.date("2026-11-20T09:00")

    private func dates(_ times: [String]) -> [Date] {
        times.enumerated().map { index, time in TestClock.date(String(format: "2026-11-%02dT%@", index + 1, time)) }
    }

    /// Une nuit endormie sans phase, de `asleep` jusqu'à 7 h le matin de `wake`.
    private func night(_ asleep: String, wakingOn wake: String) -> CachedHealthSample {
        CachedHealthSample(kind: .sleep, start: TestClock.date(asleep), end: TestClock.date("\(wake)T07:00"),
                           sleepStage: .asleepUnspecified, fetchedAt: now)
    }

    // MARK: Médiane

    @Test func fewerThanFiveNightsGiveNoHabitualTime() {
        #expect(HabitualBedtime.minutes(fellAsleep: dates(["23:00", "23:10", "23:20", "23:30"]), calendar: calendar) == nil)
        #expect(HabitualBedtime.minutes(fellAsleep: [], calendar: calendar) == nil)
    }

    @Test func oddCountTakesTheMiddleNight() {
        let times = dates(["22:50", "23:40", "23:05", "23:20", "22:30"])
        #expect(HabitualBedtime.minutes(fellAsleep: times, calendar: calendar) == 23 * 60 + 5)
    }

    @Test func nightsAroundMidnightGiveAMedianNearMidnightNotNoon() {
        let times = dates(["23:30", "00:30", "23:30", "00:30", "23:30", "00:30"])
        #expect(HabitualBedtime.minutes(fellAsleep: times, calendar: calendar) == 0)
        let later = dates(["23:50", "00:20", "00:40", "01:00", "00:10"])
        #expect(HabitualBedtime.minutes(fellAsleep: later, calendar: calendar) == 20)
    }

    @Test func evenCountAveragesAndRoundsToFiveMinutes() {
        // 23:02 et 23:09 → 23:05,5 → 23:05.
        let times = dates(["22:40", "23:02", "23:09", "23:30", "22:50", "23:45"])
        #expect(HabitualBedtime.minutes(fellAsleep: times, calendar: calendar) == 23 * 60 + 5)
    }

    @Test func reminderComesThirtyMinutesBeforeAcrossMidnight() {
        #expect(HabitualBedtime.reminderMinutes(habitual: 23 * 60 + 10) == 22 * 60 + 40)
        #expect(HabitualBedtime.reminderMinutes(habitual: 15) == 23 * 60 + 45)
        #expect(HabitualBedtime.reminderMinutes(habitual: 0) == 23 * 60 + 30)
    }

    // MARK: Cache

    @Test func readerUsesTheLastFourteenNightsOfTheCache() async throws {
        let cache = InMemoryHealthSampleCache()
        // Deux vieilles nuits très tardives hors fenêtre, puis cinq nuits récentes autour de minuit.
        try await cache.insert([night("2026-11-01T03:00", wakingOn: "2026-11-01"),
                                night("2026-11-02T03:00", wakingOn: "2026-11-02")])
        try await cache.insert([
            night("2026-11-13T23:30", wakingOn: "2026-11-14"), night("2026-11-15T00:30", wakingOn: "2026-11-15"),
            night("2026-11-16T23:40", wakingOn: "2026-11-17"), night("2026-11-19T00:10", wakingOn: "2026-11-19"),
            night("2026-11-19T23:50", wakingOn: "2026-11-20")
        ])
        let reader = HabitualBedtimeReader(cache: cache, calendar: calendar)
        #expect(await reader.fellAsleepTimes(now: now).count == 5)
        #expect(await reader.minutes(now: now) == 23 * 60 + 50)
    }

    @Test func readerWithTooFewNightsKeepsTheFixedTime() async throws {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert([night("2026-11-18T23:00", wakingOn: "2026-11-19"),
                                night("2026-11-19T23:00", wakingOn: "2026-11-20")])
        #expect(await HabitualBedtimeReader(cache: cache, calendar: calendar).minutes(now: now) == nil)
    }

    // MARK: Planification

    @Test func aFollowingSupplementIsPlannedThirtyMinutesBeforeTheHabitualTime() {
        let magnesium = Fixture.supplement("Magnésium", timing: .bedtime, minutes: 22 * 60 + 30)
        let melatonin = Fixture.supplement("Mélatonine", timing: .bedtime, minutes: 21 * 60, order: 1)
        var schedule = Fixture.schedule([magnesium, melatonin])
        schedule.habitualBedtimeMinutes = 23 * 60 + 10
        schedule.followingNights = [magnesium.id]
        let day = TestClock.date("2026-11-20T00:00")
        #expect(schedule.plannedMinutes(of: magnesium, on: day) == 22 * 60 + 40)
        #expect(schedule.plannedMinutes(of: melatonin, on: day) == 21 * 60)
        #expect(schedule.followsNights(magnesium) && !schedule.followsNights(melatonin))

        let reminders = SupplementReminderPlanner.reminders(schedule: schedule, now: now, enabled: true)
        #expect(reminders.first { $0.supplementID == magnesium.id }?.fireDate == TestClock.date("2026-11-20T22:40"))
    }

    @Test func withoutAHabitualTimeAFollowingSupplementKeepsItsFixedTime() {
        let magnesium = Fixture.supplement("Magnésium", timing: .bedtime, minutes: 22 * 60 + 15)
        var schedule = Fixture.schedule([magnesium])
        schedule.followingNights = [magnesium.id]
        #expect(schedule.plannedMinutes(of: magnesium, on: TestClock.date("2026-11-20T00:00")) == 22 * 60 + 15)
        #expect(!schedule.followsNights(magnesium))
    }

    // MARK: Service

    @Test func serviceFollowsNightsOnlyForBedtimeSupplementsAndKeepsTheSettingLocal() async throws {
        let cache = InMemoryHealthSampleCache()
        try await cache.insert((14...20).map { day in
            night(String(format: "2026-11-%02dT23:10", day - 1), wakingOn: String(format: "2026-11-%02d", day))
        })
        let store = InMemorySupplementBedtimeStore()
        let reminders = StubSupplementReminderScheduler()
        let repository = InMemorySupplementRepository()
        let now = now
        let service = SupplementService(
            supplements: repository, programs: InMemoryProgramRepository(), profiles: InMemoryProfileRepository(),
            workouts: InMemoryWorkoutRepository(), reminders: reminders, health: nil,
            bedtime: HabitualBedtimeReader(cache: cache, calendar: calendar), bedtimeStore: store, calendar: calendar,
            now: { now })
        let magnesium = Fixture.supplement("Magnésium", timing: .bedtime, minutes: 22 * 60 + 30)
        let creatine = Fixture.supplement(minutes: 20 * 60, order: 1)
        try await service.save(magnesium, followsNights: true)
        try await service.save(creatine, followsNights: true)

        #expect(store.followingNights == [magnesium.id])
        let overview = try await service.overview()
        #expect(overview.habitualBedtimeMinutes == 23 * 60 + 10)
        #expect(overview.followingNights == [magnesium.id])
        #expect(overview.items.first { $0.supplement.id == magnesium.id }?.plannedMinutes == 22 * 60 + 40)
        // Le magasin synchronisé garde l'heure fixe : l'heure déduite n'y est jamais écrite.
        let stored = try await repository.supplements(includeArchived: false).first { $0.id == magnesium.id }
        #expect(stored?.timeOfDayMinutes == 22 * 60 + 30)

        try await service.save(magnesium, followsNights: false)
        #expect(store.followingNights.isEmpty)
        #expect(try await service.overview().items.first { $0.supplement.id == magnesium.id }?.plannedMinutes == 22 * 60 + 30)
    }
}
