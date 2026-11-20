import Foundation
import PulseDomain
import PulseServices
import Testing

struct PlanningServiceTests {
    private typealias Fixture = PlanningFixtures
    private let profiles = InMemoryProfileRepository()
    private let programs = InMemoryProgramRepository()
    private let workouts = InMemoryWorkoutRepository()
    private let scheduled = InMemoryScheduledDayRepository()
    private let clock = MutableClock("2026-11-18T12:00")
    private let service: PlanningService

    init() {
        let clock = clock
        service = PlanningService(profiles: profiles, programs: programs, workouts: workouts, scheduledDays: scheduled,
                                  calendar: TestClock.calendar, now: { clock.now })
    }

    private func setUp(onboarded: String = "2026-10-01T08:00") async throws {
        try await programs.save(Fixture.program())
        try await profiles.save(UserProfile(restWeekdays: [.sunday], onboardingCompletedAt: TestClock.date(onboarded),
                                            activeProgramID: Fixture.programID))
    }

    private func day(_ text: String) -> Date {
        TestClock.date("\(text)T00:00")
    }

    @Test func overviewReadsTheWeekAndTheStreak() async throws {
        try await setUp()
        for text in ["2026-11-09T18:00", "2026-11-10T18:00", "2026-11-11T18:00", "2026-11-12T18:00", "2026-11-13T18:00",
                     "2026-11-16T18:00"] {
            try await workouts.save(Fixture.session(text))
        }
        let overview = try await service.overview()
        #expect(overview.days.count == 7 && overview.days[0].state == .done && overview.days[1].state == .missed)
        #expect(overview.streak.streak == 1 && overview.streak.currentWeek?.count == 1)
        #expect(overview.historyStart == TestClock.date("2026-10-01T08:00"))
        #expect(!overview.hasUserMoves)
    }

    @Test func swapExchangesTwoDaysAndSwappingBackRestoresTheTemplate() async throws {
        try await setUp()
        try await service.swap(day("2026-11-19"), day("2026-11-21"))

        var overview = try await service.overview()
        #expect(overview.days[3].routine == nil && overview.days[3].state == .rest)
        #expect(overview.days[5].routine?.name == "Endurance" && overview.days[5].movedFrom == day("2026-11-19"))
        #expect(overview.hasUserMoves)

        try await service.swap(day("2026-11-21"), day("2026-11-19"))
        overview = try await service.overview()
        #expect(overview.days[3].routine?.name == "Endurance" && overview.days[5].routine == nil)
        #expect(try await scheduled.days(from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test func aMovedSessionKeepsItsFirstOrigin() async throws {
        try await setUp()
        try await service.swap(day("2026-11-18"), day("2026-11-21"))
        try await service.swap(day("2026-11-21"), day("2026-11-22"))
        let overview = try await service.overview()
        #expect(overview.days[6].routine?.name == "Legs" && overview.days[6].movedFrom == day("2026-11-18"))
    }

    @Test func pastDoneOrEmptyDaysCannotMove() async throws {
        try await setUp()
        try await workouts.save(Fixture.session("2026-11-18T08:00"))
        await #expect(throws: PlanningError.notMovable) { try await service.swap(day("2026-11-17"), day("2026-11-19")) }
        await #expect(throws: PlanningError.notMovable) { try await service.swap(day("2026-11-18"), day("2026-11-19")) }
        await #expect(throws: PlanningError.notMovable) { try await service.swap(day("2026-11-21"), day("2026-11-22")) }
        await #expect(throws: PlanningError.notMovable) { try await service.swap(day("2026-11-19"), day("2026-11-24")) }
    }

    @Test func swapWithoutProgramFails() async throws {
        try await profiles.save(UserProfile())
        await #expect(throws: PlanningError.noProgram) { try await service.swap(day("2026-11-19"), day("2026-11-21")) }
    }

    @Test func restoreWeekRemovesUserMovesOnly() async throws {
        try await setUp()
        var rule = Fixture.moved(nil, on: "2026-11-20", from: nil)
        rule.moveReason = .antiInterferenceRestDay
        try await scheduled.save(rule)
        try await service.swap(day("2026-11-19"), day("2026-11-21"))

        try await service.restoreWeek()
        #expect(try await scheduled.days(from: .distantPast, to: .distantFuture).map(\.id) == [rule.id])
    }

    @Test func monthReadsItsVisibleRange() async throws {
        try await setUp()
        try await workouts.save(Fixture.session("2026-10-27T18:00"))
        let grid = try await service.month(TestClock.date("2026-11-05T10:00"))
        #expect(grid.weeks.first?[1].done == [.strength])
    }
}
