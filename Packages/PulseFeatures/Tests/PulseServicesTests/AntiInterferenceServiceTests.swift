import Foundation
import PulseContent
import PulseDomain
import PulseServices
import Testing

struct AntiInterferenceServiceTests {
    private typealias Fixture = RuleFixtures
    private let profiles = InMemoryProfileRepository()
    private let programs = InMemoryProgramRepository()
    private let workouts = InMemoryWorkoutRepository()
    private let scheduled = InMemoryScheduledDayRepository()
    private let clock = MutableClock("2026-11-16T07:00")
    private let service: AntiInterferenceService
    private let planning: PlanningService

    init() {
        let clock = clock
        service = AntiInterferenceService(profiles: profiles, programs: programs, workouts: workouts, scheduledDays: scheduled,
                                          userExercises: InMemoryUserExerciseRepository(), library: .bundled,
                                          calendar: TestClock.calendar, now: { clock.now })
        planning = PlanningService(profiles: profiles, programs: programs, workouts: workouts, scheduledDays: scheduled,
                                   calendar: TestClock.calendar, now: { clock.now })
    }

    private func setUp(disabled: [AntiInterferenceRule] = []) async throws {
        try await programs.save(Fixture.program())
        try await profiles.save(UserProfile(restWeekdays: [.sunday], antiInterferenceRulesDisabled: disabled,
                                            onboardingCompletedAt: Fixture.created, activeProgramID: Fixture.programID))
    }

    private func lines() async throws -> [ScheduledDay] {
        try await scheduled.days(from: .distantPast, to: .distantFuture)
    }

    @Test func writesTheMoveOnceAndKeepsItAcrossPasses() async throws {
        try await setUp()
        try await service.apply(nights: [])
        let first = try await lines()
        #expect(first.map(\.date) == [Fixture.day("2026-11-19"), Fixture.day("2026-11-21")])
        #expect(first[1].moveReasonText == "Déplacée : 36 h après les jambes" && first[1].kind == .run)

        try await service.apply(nights: [])
        #expect(try await lines() == first, "Un second passage ne réécrit rien")

        let overview = try await planning.overview()
        #expect(overview.days[3].routine == nil && overview.days[5].routine?.id == Fixture.intervals.id)
        #expect(!overview.hasUserMoves)
    }

    @Test func disablingTheRuleRemovesItsFutureLines() async throws {
        try await setUp()
        try await service.apply(nights: [])
        var profile = try #require(try await profiles.load())
        profile.antiInterferenceRulesDisabled = [.noIntenseRunAfterHeavyLegs]
        try await profiles.save(profile)
        try await service.apply(nights: [])
        #expect(try await lines().isEmpty)
    }

    @Test func aMoveWhoseOriginIsPastSurvivesDisablingTheRule() async throws {
        try await setUp()
        try await service.apply(nights: [])
        clock.set("2026-11-20T09:00")
        var profile = try #require(try await profiles.load())
        profile.antiInterferenceRulesDisabled = [.noIntenseRunAfterHeavyLegs]
        try await profiles.save(profile)
        try await service.apply(nights: [])
        #expect(try await lines().map(\.date) == [Fixture.day("2026-11-19"), Fixture.day("2026-11-21")],
                "Le jeudi est passé : le samedi garde la course qui en est partie, sinon elle disparaîtrait")
    }

    @Test func keepingThePlannedDayRestoresBothDaysAndLocksThem() async throws {
        try await setUp()
        try await service.apply(nights: [])
        try await planning.keepPlanned(Fixture.day("2026-11-21"))
        var overview = try await planning.overview()
        #expect(overview.days[3].routine?.id == Fixture.intervals.id && overview.days[5].routine == nil)
        #expect(try await lines().allSatisfy { $0.moveReason == .user && $0.movedFromDate == nil })
        #expect(overview.hasUserMoves)

        try await service.apply(nights: [])
        overview = try await planning.overview()
        #expect(overview.days[3].routine?.id == Fixture.intervals.id, "Le refus vaut pour cette date")

        try await planning.restoreWeek()
        try await service.apply(nights: [])
        #expect(try await planning.overview().days[5].routine?.id == Fixture.intervals.id, "Rétablir rend la main aux règles")
    }

    @Test func keepingADayWithoutRuleLineIsRefused() async throws {
        try await setUp()
        await #expect(throws: PlanningError.notMovable) { try await planning.keepPlanned(Fixture.day("2026-11-18")) }
    }

    @Test func swappingARuleMovedDayDoesNotDuplicateTheRun() async throws {
        try await setUp()
        try await service.apply(nights: [])
        try await planning.swap(Fixture.day("2026-11-21"), Fixture.day("2026-11-20"))
        try await service.apply(nights: [])
        let routines = try await planning.overview().days.map(\.routine?.id)
        #expect(routines.filter { $0 == Fixture.intervals.id }.count == 1)
        #expect(routines[4] == Fixture.intervals.id && routines[5] == Fixture.push.id && routines[3] == nil)
    }

    @Test func nothingHappensWithoutAProgram() async throws {
        try await profiles.save(UserProfile(onboardingCompletedAt: Fixture.created))
        try await service.apply(nights: [])
        #expect(try await lines().isEmpty)
    }

    @Test func theMoveSurvivesOnceItsOriginIsPast() async throws {
        try await setUp()
        try await service.apply(nights: [])
        let lines = try await lines()
        clock.set("2026-11-20T09:00")
        try await service.apply(nights: [])
        #expect(try await self.lines() == lines)
        #expect(try await planning.overview().days[5].routine?.id == Fixture.intervals.id)
    }

    @Test func swappingAMovedRunBackSticks() async throws {
        try await setUp()
        try await service.apply(nights: [])
        try await planning.swap(Fixture.day("2026-11-19"), Fixture.day("2026-11-21"))
        try await service.apply(nights: [])
        let routines = try await planning.overview().days.map(\.routine?.id)
        #expect(routines[3] == Fixture.intervals.id && routines[5] == nil, "L'échange de l'utilisateur tient")
    }
}
