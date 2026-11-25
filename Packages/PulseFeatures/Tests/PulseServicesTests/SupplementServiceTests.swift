import Foundation
import PulseDomain
import PulseServices
import Testing

struct SupplementServiceTests {
    private typealias Fixture = SupplementFixtures
    private let repository = InMemorySupplementRepository()
    private let programs = InMemoryProgramRepository()
    private let profiles = InMemoryProfileRepository()
    private let workouts = InMemoryWorkoutRepository()
    private let reminders = StubSupplementReminderScheduler()
    private let health: StubSupplementHealthWriter
    private let clock = MutableClock("2026-11-20T09:00")
    private let service: SupplementService

    init() {
        health = StubSupplementHealthWriter()
        let clock = clock
        service = SupplementService(supplements: repository, programs: programs, profiles: profiles, workouts: workouts,
                                    reminders: reminders, health: health, calendar: TestClock.calendar, now: { clock.now })
    }

    private func stored(_ id: UUID) async throws -> Supplement? {
        try await repository.supplements(includeArchived: true).first { $0.id == id }
    }

    private func allIntakes() async throws -> [SupplementIntake] {
        try await repository.intakes(from: .distantPast, to: .distantFuture)
    }

    @Test func overviewUsesTheActiveProgramForTrainingDays() async throws {
        let program = Fixture.program()
        try await programs.save(program)
        try await profiles.save(UserProfile(activeProgramID: program.id))
        let whey = Fixture.supplement("Whey", timing: .afterWorkout, minutes: nil, days: .trainingDays)
        try await service.save(whey)

        let overview = try await service.overview()
        #expect(overview.items.map(\.supplement.id) == [whey.id])
        #expect(overview.workoutItems.count == 1 && overview.dueCount == 1 && overview.takenCount == 0)
        #expect(overview.next?.supplement.id == whey.id)
    }

    @Test func takeLowersStockWritesToHealthAndNeverCountsTwice() async throws {
        let vitamin = Fixture.supplement("Vitamine D3", unit: .iu, dose: 1_000, stock: 10, threshold: 9, health: .vitaminD)
        try await service.save(vitamin)

        #expect(try await service.take(supplementID: vitamin.id))
        #expect(try await !service.take(supplementID: vitamin.id))

        let intakes = try await allIntakes()
        #expect(intakes.count == 1)
        #expect(intakes[0].takenAt == clock.now && intakes[0].writtenToHealthKit)
        #expect(try await stored(vitamin.id)?.stockDoses == 9)
        #expect(try await stored(vitamin.id)?.isLowOnStock == true)
        #expect(await health.saved.values.map(\.amount) == [25])
        #expect(await health.saved.values.map(\.type) == [.vitaminD])
        #expect(try await service.overview().takenCount == 1)
    }

    @Test func untakeRestoresStockAndDeletesTheSample() async throws {
        let caffeine = Fixture.supplement("Caféine", unit: .mg, dose: 200, stock: 5, health: .caffeine)
        try await service.save(caffeine)
        try await service.take(supplementID: caffeine.id)
        let sample = try #require(try await allIntakes().first?.healthKitUUID.flatMap(UUID.init(uuidString:)))

        try await service.untake(supplementID: caffeine.id)
        #expect(try await allIntakes().isEmpty)
        #expect(try await stored(caffeine.id)?.stockDoses == 5)
        #expect(await health.deleted == [sample])
    }

    @Test func aFailedHealthWriteIsRetriedLater() async throws {
        await health.setFailsOnSave(true)
        let magnesium = Fixture.supplement("Magnésium", unit: .mg, dose: 300, health: .magnesium)
        try await service.save(magnesium)
        try await service.take(supplementID: magnesium.id)
        #expect(try await allIntakes().first?.writtenToHealthKit == false)

        await health.setFailsOnSave(false)
        await service.retryHealthWrites()
        #expect(try await allIntakes().first?.writtenToHealthKit == true)
        #expect(await health.saved.count == 1)
        await service.retryHealthWrites()
        #expect(await health.saved.count == 1)
    }

    @Test func noHealthWriteWithoutAccessOrConvertibleUnit() async throws {
        let denied = StubSupplementHealthWriter(access: .denied)
        let clock = clock
        let service = SupplementService(supplements: repository, programs: programs, profiles: profiles, workouts: workouts,
                                        reminders: nil, health: denied, calendar: TestClock.calendar, now: { clock.now })
        let whey = Fixture.supplement("Whey", unit: .serving, dose: 1, health: .protein)
        let vitamin = Fixture.supplement("Vitamine D3", unit: .iu, dose: 1_000, health: .vitaminD, order: 1)
        try await service.save(whey)
        try await service.save(vitamin)
        try await service.take(supplementID: whey.id)
        try await service.take(supplementID: vitamin.id)
        #expect(await denied.saved.isEmpty)
        #expect(try await allIntakes().allSatisfy { !$0.writtenToHealthKit })
    }

    @Test func aReminderActionAfterMidnightCountsForItsOwnDay() async throws {
        let magnesium = Fixture.supplement("Magnésium", timing: .bedtime, minutes: 23 * 60 + 30)
        try await service.save(magnesium)
        clock.set("2026-11-21T00:20")
        try await service.take(supplementID: magnesium.id, day: TestClock.date("2026-11-20T00:00"))
        #expect(try await allIntakes().first?.takenAt == TestClock.date("2026-11-20T23:59"))
    }

    @Test func remindersFollowEverySaveAndTake() async throws {
        let creatine = Fixture.supplement(minutes: 20 * 60)
        try await service.save(creatine)
        #expect(await reminders.replaceCount == 1)
        #expect(await reminders.reminders.first?.fireDate == TestClock.date("2026-11-20T20:00"))

        try await service.take(supplementID: creatine.id)
        #expect(await reminders.reminders.first?.fireDate == TestClock.date("2026-11-21T20:00"))

        try await profiles.save(UserProfile(supplementRemindersEnabled: false))
        await service.rescheduleReminders()
        #expect(await reminders.reminders.isEmpty)
    }

    @Test func archiveRemovesFromTheDayAndOrderGoesAfterTheLast() async throws {
        let first = Fixture.supplement(order: 0)
        let second = Fixture.supplement("Zinc", order: 4)
        try await service.save(first)
        try await service.save(second)
        #expect(try await service.nextOrder() == 5)

        try await service.archive(id: second.id)
        #expect(try await service.overview().supplements.map(\.id) == [first.id])
        #expect(try await service.nextOrder() == 5)
    }

    @Test func unarchiveBringsItBackInPlaceAndReschedulesItsReminders() async throws {
        let first = Fixture.supplement(order: 0)
        let zinc = Fixture.supplement("Zinc", minutes: 21 * 60, order: 1)
        try await service.save(first)
        try await service.save(zinc)
        try await service.archive(id: zinc.id)
        let archivedOverview = try await service.overview()
        #expect(archivedOverview.archived.map(\.id) == [zinc.id])
        #expect(await !reminders.reminders.contains { $0.supplementID == zinc.id })
        let replacements = await reminders.replaceCount

        try await service.unarchive(id: zinc.id)
        let overview = try await service.overview()
        #expect(overview.supplements.map(\.id) == [first.id, zinc.id])
        #expect(overview.archived.isEmpty)
        #expect(try await stored(zinc.id)?.isArchived == false)
        #expect(await reminders.replaceCount == replacements + 1)
        #expect(await reminders.reminders.contains { $0.supplementID == zinc.id })

        try await service.unarchive(id: zinc.id)
        #expect(await reminders.replaceCount == replacements + 1)
    }

    /// Le Push du vendredi déplacé au samedi dans le Planning : la caféine d'avant la séance suit la semaine réelle.
    @Test func trainingDayRemindersFollowThePlanningMoves() async throws {
        let program = Fixture.program()
        try await programs.save(program)
        try await profiles.save(UserProfile(activeProgramID: program.id))
        let scheduled = InMemoryScheduledDayRepository()
        let friday = TestClock.date("2026-11-20T00:00")
        let saturday = TestClock.date("2026-11-21T00:00")
        let push = try #require(program.days.first)
        try await scheduled.save(ScheduledDay(date: friday, programID: program.id, title: "Repos", kind: .rest, status: .planned,
                                              moveReason: .user, createdAt: friday, updatedAt: friday))
        try await scheduled.save(ScheduledDay(date: saturday, programID: program.id, routineDayID: push.id, title: push.name,
                                              kind: .strength, status: .planned, movedFromDate: friday, moveReason: .user,
                                              createdAt: friday, updatedAt: friday))
        let clock = clock
        let moved = SupplementService(supplements: repository, programs: programs, profiles: profiles, workouts: workouts,
                                      reminders: reminders, health: health, scheduledDays: scheduled, calendar: TestClock.calendar,
                                      now: { clock.now })
        try await moved.save(Fixture.supplement("Caféine", timing: .beforeWorkout, minutes: nil, days: .trainingDays))

        let days = await reminders.reminders.map(\.day)
        #expect(!days.contains(friday) && days.first == saturday)
        #expect(await reminders.reminders.first?.fireDate == TestClock.date("2026-11-21T17:30"))
        #expect(try await moved.overview().items.isEmpty, "Le vendredi devient un jour de repos")
    }
}
