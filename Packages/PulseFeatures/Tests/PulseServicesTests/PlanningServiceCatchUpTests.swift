import Foundation
import PulseDomain
import PulseServices
import Testing

struct PlanningServiceCatchUpTests {
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

    private func setUp() async throws {
        try await programs.save(Fixture.program())
        try await profiles.save(UserProfile(restWeekdays: [.sunday], onboardingCompletedAt: TestClock.date("2026-10-01T08:00"),
                                            activeProgramID: Fixture.programID))
    }

    private func day(_ text: String) -> Date {
        TestClock.date("\(text)T00:00")
    }

    @Test func catchUpPutsTheMissedSessionOnARestDay() async throws {
        try await setUp()
        try await service.catchUp(day("2026-11-17"), on: day("2026-11-21"))

        let overview = try await service.overview()
        #expect(overview.days[1].state == .caughtUp)
        #expect(overview.days[5].routine?.name == "Pull" && overview.days[5].movedFrom == day("2026-11-17"))
        #expect(overview.days[2].routine?.name == "Legs" && overview.days[3].routine?.name == "Endurance")
        #expect(overview.hasUserMoves)
    }

    @Test func restoreWeekUndoesTheCatchUp() async throws {
        try await setUp()
        try await service.catchUp(day("2026-11-17"), on: day("2026-11-21"))
        try await service.restoreWeek()
        let overview = try await service.overview()
        #expect(overview.days[1].state == .missed && overview.days[5].routine == nil)
    }

    @Test func aPastWeekCannotBeCaughtUp() async throws {
        try await setUp()
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-10"), on: day("2026-11-21")) }
    }

    @Test func onlyAMissedDayToAComingDayOfTheWeek() async throws {
        try await setUp()
        try await workouts.save(Fixture.session("2026-11-16T18:00"))
        // Lundi est validé, mercredi n'est pas passé, mardi ne va pas sur lundi, ni sur le repos imposé, ni la semaine suivante.
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-16"), on: day("2026-11-21")) }
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-18"), on: day("2026-11-21")) }
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-17"), on: day("2026-11-16")) }
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-17"), on: day("2026-11-22")) }
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-17"), on: day("2026-11-24")) }
        #expect(try await scheduled.days(from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test func aSessionCannotBeCaughtUpTwice() async throws {
        try await setUp()
        try await service.catchUp(day("2026-11-17"), on: day("2026-11-21"))
        await #expect(throws: PlanningError.notMovable) { try await service.catchUp(day("2026-11-17"), on: day("2026-11-19")) }
    }

    @Test func catchUpWithoutProgramFails() async throws {
        try await profiles.save(UserProfile())
        await #expect(throws: PlanningError.noProgram) { try await service.catchUp(day("2026-11-17"), on: day("2026-11-21")) }
    }
}
